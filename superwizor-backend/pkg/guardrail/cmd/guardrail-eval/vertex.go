package main

import (
	"context"
	"fmt"
	"os"
	"strings"

	"google.golang.org/genai"

	"github.com/superwizor-ai/backend/pkg/guardrail"
)

// vertexCaller is the live-mode model backend. It lives in the runner
// rather than in pkg/guardrail so the guardrail module itself stays free
// of an LLM SDK and its unit tests need no credentials.
type vertexCaller struct{ client *genai.Client }

func newVertexCaller(ctx context.Context) (guardrail.ModelCaller, error) {
	project := strings.TrimSpace(os.Getenv("GOOGLE_CLOUD_PROJECT"))
	if project == "" {
		return nil, fmt.Errorf("GOOGLE_CLOUD_PROJECT is not set")
	}
	location := strings.TrimSpace(os.Getenv("VERTEX_LOCATION"))
	if location == "" {
		location = "europe-west4"
	}
	c, err := genai.NewClient(ctx, &genai.ClientConfig{
		Project: project, Location: location, Backend: genai.BackendVertexAI,
	})
	if err != nil {
		return nil, err
	}
	return &vertexCaller{client: c}, nil
}

func (v *vertexCaller) CallJSON(ctx context.Context, model, sys, user string, schema map[string]any, temp float32) (string, guardrail.Cost, error) {
	cfg := &genai.GenerateContentConfig{
		Temperature:      genai.Ptr(temp),
		ResponseMIMEType: "application/json",
	}
	if sys != "" {
		cfg.SystemInstruction = genai.NewContentFromText(sys, genai.RoleUser)
	}
	if schema != nil {
		s, err := toSchema(schema)
		if err != nil {
			return "", guardrail.Cost{}, err
		}
		cfg.ResponseSchema = s
	}

	resp, err := v.client.Models.GenerateContent(ctx, model, genai.Text(user), cfg)
	if err != nil {
		return "", guardrail.Cost{}, err
	}
	var cost guardrail.Cost
	cost.Model = model
	if resp.UsageMetadata != nil {
		cost.InputTokens = int64(resp.UsageMetadata.PromptTokenCount)
		cost.OutputTokens = int64(resp.UsageMetadata.CandidatesTokenCount)
	}
	var sb strings.Builder
	for _, cand := range resp.Candidates {
		if cand.Content == nil {
			continue
		}
		for _, part := range cand.Content.Parts {
			sb.WriteString(part.Text)
		}
	}
	return sb.String(), cost, nil
}

// toSchema converts the guardrail JSON Schema subset to genai's type.
// An unsupported construct is an error, never a silent omission: dropping
// a "required" or an "enum" would remove exactly the constraint the eval
// is measuring.
func toSchema(m map[string]any) (*genai.Schema, error) {
	s := &genai.Schema{}
	switch t, _ := m["type"].(string); t {
	case "object":
		s.Type = genai.TypeObject
		if props, ok := m["properties"].(map[string]any); ok {
			s.Properties = map[string]*genai.Schema{}
			for k, raw := range props {
				sub, ok := raw.(map[string]any)
				if !ok {
					return nil, fmt.Errorf("property %q is not an object", k)
				}
				child, err := toSchema(sub)
				if err != nil {
					return nil, fmt.Errorf("property %q: %w", k, err)
				}
				s.Properties[k] = child
			}
		}
		if req, ok := m["required"].([]any); ok {
			for _, r := range req {
				if rs, ok := r.(string); ok {
					s.Required = append(s.Required, rs)
				}
			}
		}
	case "array":
		s.Type = genai.TypeArray
		items, ok := m["items"].(map[string]any)
		if !ok {
			return nil, fmt.Errorf("array without items")
		}
		child, err := toSchema(items)
		if err != nil {
			return nil, err
		}
		s.Items = child
	case "string":
		s.Type = genai.TypeString
		if e, ok := m["enum"].([]any); ok {
			for _, v := range e {
				if vs, ok := v.(string); ok {
					s.Enum = append(s.Enum, vs)
				}
			}
		}
	case "number":
		s.Type = genai.TypeNumber
	case "integer":
		s.Type = genai.TypeInteger
	case "boolean":
		s.Type = genai.TypeBoolean
	default:
		return nil, fmt.Errorf("unsupported schema type %q", t)
	}
	if d, ok := m["description"].(string); ok {
		s.Description = d
	}
	return s, nil
}
