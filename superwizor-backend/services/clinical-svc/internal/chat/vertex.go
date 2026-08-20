package chat

import (
	"context"
	"fmt"
	"os"
	"strings"

	"google.golang.org/genai"
)

// VertexConfig configures the Vertex AI backend.
type VertexConfig struct {
	ProjectID string
	// Location is the Vertex region. It comes from the environment, never
	// from a constant in this file: the client app hard-coded its region
	// once already, and a data-residency setting that can only be changed
	// by editing Go is not a setting.
	//
	// As of 2026-08-20 the platform runs europe-west4 (Gemini 2.x, EU
	// residency). No EU region serves any Gemini 3.x model.
	Location string
}

// VertexConfigFromEnv reads the backend configuration.
//
// GOOGLE_CLOUD_PROJECT empty means "no model backend" and is a supported
// state, not an error: local dev and CI run the service with chat off.
func VertexConfigFromEnv() VertexConfig {
	loc := strings.TrimSpace(os.Getenv("VERTEX_LOCATION"))
	if loc == "" {
		loc = "europe-west4"
	}
	return VertexConfig{
		ProjectID: strings.TrimSpace(os.Getenv("GOOGLE_CLOUD_PROJECT")),
		Location:  loc,
	}
}

type vertexLLM struct {
	client *genai.Client
	cfg    VertexConfig
}

// NewVertexLLM builds the Vertex-backed LLM. With an empty ProjectID it
// returns NopLLM and no error — see VertexConfigFromEnv.
func NewVertexLLM(ctx context.Context, cfg VertexConfig) (LLM, error) {
	if cfg.ProjectID == "" {
		return NopLLM(), nil
	}
	c, err := genai.NewClient(ctx, &genai.ClientConfig{
		Project:  cfg.ProjectID,
		Location: cfg.Location,
		Backend:  genai.BackendVertexAI,
	})
	if err != nil {
		return nil, fmt.Errorf("chat: vertex client: %w", err)
	}
	return &vertexLLM{client: c, cfg: cfg}, nil
}

func (v *vertexLLM) Generate(ctx context.Context, req GenerateRequest) (GenerateResponse, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()

	cfg := &genai.GenerateContentConfig{
		Temperature: genai.Ptr(req.Temperature),
	}
	if req.MaxTokens > 0 {
		cfg.MaxOutputTokens = req.MaxTokens
	}
	if req.SystemPrompt != "" {
		cfg.SystemInstruction = genai.NewContentFromText(req.SystemPrompt, genai.RoleUser)
	}
	if req.ResponseSchema != nil {
		cfg.ResponseMIMEType = "application/json"
		schema, err := toGenaiSchema(req.ResponseSchema)
		if err != nil {
			return GenerateResponse{}, wrapModelErr(req.Model, err)
		}
		cfg.ResponseSchema = schema
	}

	resp, err := v.client.Models.GenerateContent(ctx, req.Model,
		genai.Text(req.UserContent), cfg)
	if err != nil {
		return GenerateResponse{}, wrapModelErr(req.Model, err)
	}

	out := GenerateResponse{Model: req.Model}
	if resp.UsageMetadata != nil {
		out.Usage = Usage{
			InputTokens:  int64(resp.UsageMetadata.PromptTokenCount),
			OutputTokens: int64(resp.UsageMetadata.CandidatesTokenCount),
		}
	}
	var sb strings.Builder
	for _, cand := range resp.Candidates {
		// MaxTokens jako powod zakonczenia = wyjscie UCIETE. Dla
		// odpowiedzi strukturalnej to prawie na pewno niedomkniety JSON,
		// ktory dalej wyglada jak "model zwrocil smieci" — a naprawde to
		// my dalismy za maly limit. Flaga pozwala wywolujacemu ponowic z
		// wiekszym budzetem zamiast blokowac ture.
		if cand.FinishReason == genai.FinishReasonMaxTokens {
			out.Truncated = true
		}
		if cand.Content == nil {
			continue
		}
		for _, part := range cand.Content.Parts {
			sb.WriteString(part.Text)
		}
	}
	out.Text = sb.String()

	// An empty body with a successful status is usually a safety block or
	// a truncated generation. Treated as an error: downstream, an empty
	// string would validate as "no hypotheses" and be shown as a real,
	// confident, empty answer.
	if strings.TrimSpace(out.Text) == "" {
		return out, wrapModelErr(req.Model, fmt.Errorf("empty response body"))
	}
	return out, nil
}

func (v *vertexLLM) Embed(ctx context.Context, text string) ([]float32, Usage, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()

	resp, err := v.client.Models.EmbedContent(ctx, EmbeddingModel,
		[]*genai.Content{genai.NewContentFromText(text, genai.RoleUser)}, nil)
	if err != nil {
		return nil, Usage{}, wrapModelErr(EmbeddingModel, err)
	}
	if len(resp.Embeddings) == 0 || len(resp.Embeddings[0].Values) == 0 {
		return nil, Usage{}, wrapModelErr(EmbeddingModel, fmt.Errorf("no embedding returned"))
	}
	vec := resp.Embeddings[0].Values
	if len(vec) != EmbeddingDims {
		// A dimension mismatch would be silently truncated or rejected by
		// pgvector at insert time, far from the cause.
		return nil, Usage{}, wrapModelErr(EmbeddingModel,
			fmt.Errorf("got %d dimensions, column expects %d", len(vec), EmbeddingDims))
	}
	// Embedding calls bill input tokens only; the API does not always
	// report them, and a missing count must not silently zero the charge.
	var usage Usage
	if resp.Metadata != nil {
		usage.InputTokens = int64(resp.Metadata.BillableCharacterCount)
	}
	return vec, usage, nil
}

// toGenaiSchema converts a JSON Schema (as used in pkg/guardrail/schemas)
// into the genai schema type.
//
// Only the subset the guardrail schemas actually use is supported, and an
// unsupported construct is an error rather than a silent omission: a
// dropped "required" or a dropped "minItems" would quietly remove exactly
// the constraint the schema exists to enforce.
func toGenaiSchema(m map[string]any) (*genai.Schema, error) {
	s := &genai.Schema{}

	typ, _ := m["type"].(string)
	switch typ {
	case "object":
		s.Type = genai.TypeObject
		props, _ := m["properties"].(map[string]any)
		if len(props) > 0 {
			s.Properties = make(map[string]*genai.Schema, len(props))
			for k, raw := range props {
				sub, ok := raw.(map[string]any)
				if !ok {
					return nil, fmt.Errorf("schema: property %q is not an object", k)
				}
				child, err := toGenaiSchema(sub)
				if err != nil {
					return nil, fmt.Errorf("schema: property %q: %w", k, err)
				}
				s.Properties[k] = child
			}
		}
		for _, r := range toStringSlice(m["required"]) {
			s.Required = append(s.Required, r)
		}
	case "array":
		s.Type = genai.TypeArray
		items, ok := m["items"].(map[string]any)
		if !ok {
			return nil, fmt.Errorf("schema: array without items")
		}
		child, err := toGenaiSchema(items)
		if err != nil {
			return nil, fmt.Errorf("schema: items: %w", err)
		}
		s.Items = child
		if v, ok := toInt64(m["minItems"]); ok {
			s.MinItems = genai.Ptr(v)
		}
		if v, ok := toInt64(m["maxItems"]); ok {
			s.MaxItems = genai.Ptr(v)
		}
	case "string":
		s.Type = genai.TypeString
		if e := toStringSlice(m["enum"]); len(e) > 0 {
			s.Enum = e
		}
		// maxLength to kontrola rozmiaru wyjscia — bez przeniesienia jej
		// tutaj limit w schemacie guardraila bylby deklaracja bez skutku
		// i eseje dalej ucinalyby JSON na MaxTokens (incydent 20.08 19:01).
		if v, ok := toInt64(m["maxLength"]); ok {
			s.MaxLength = genai.Ptr(v)
		}
		if v, ok := toInt64(m["minLength"]); ok {
			s.MinLength = genai.Ptr(v)
		}
	case "integer":
		s.Type = genai.TypeInteger
	case "number":
		s.Type = genai.TypeNumber
	case "boolean":
		s.Type = genai.TypeBoolean
	default:
		return nil, fmt.Errorf("schema: unsupported type %q", typ)
	}

	if d, ok := m["description"].(string); ok {
		s.Description = d
	}
	return s, nil
}

func toStringSlice(v any) []string {
	raw, ok := v.([]any)
	if !ok {
		if ss, ok := v.([]string); ok {
			return ss
		}
		return nil
	}
	out := make([]string, 0, len(raw))
	for _, item := range raw {
		if s, ok := item.(string); ok {
			out = append(out, s)
		}
	}
	return out
}

func toInt64(v any) (int64, bool) {
	switch n := v.(type) {
	case int:
		return int64(n), true
	case int64:
		return n, true
	case float64:
		return int64(n), true
	}
	return 0, false
}
