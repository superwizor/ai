// Package chat implements the therapist-facing AI chat with the guardrail
// layer described in ADR docs/kronikarz/62 (v1.3).
//
// The pipeline is fixed and every turn walks all of it:
//
//	kill switch -> quota reservation -> classifier -> router
//	  -> intent executor -> schema validation -> verifier -> commit
//
// Two properties of that order are load-bearing rather than incidental:
//
//   - The quota is reserved BEFORE the classifier, so an exhausted budget
//     costs zero model calls to refuse.
//   - The verifier runs on the COMPLETE response. That is why the RPC is
//     unary: a token already streamed to a therapist cannot be recalled,
//     and the whole point of the verifier is that some responses must
//     never be shown.
package chat

import (
	"context"
	"errors"
	"fmt"
	"time"
)

// Model identifiers used by this package. Both are gemini-2.5-flash today:
// the classifier needs low latency on a short prompt, the generator needs
// clinical quality on a long one, and 2.5-flash is the only model in
// europe-west4 that is acceptable at both. They are separate constants so
// that stops being an accident the day one of them moves.
const (
	ClassifierModel = "gemini-2.5-flash"
	GeneratorModel  = "gemini-2.5-flash"
	EmbeddingModel  = "text-embedding-005"
)

// EmbeddingDims must match the pgvector column: vector(768).
const EmbeddingDims = 768

// Usage is the token accounting for one model call, taken from the
// provider's UsageMetadata rather than estimated. The quota commits
// against these numbers, so a guess here is money.
type Usage struct {
	InputTokens  int64
	OutputTokens int64
}

// GenerateRequest is one model call.
type GenerateRequest struct {
	Model string
	// SystemPrompt carries instructions only. Client material NEVER goes
	// here: ADR section 4.1 rejects control-by-system-prompt, and mixing
	// data into the instruction channel is exactly the confusion that
	// makes prompt injection work.
	SystemPrompt string
	// UserContent is the therapist's question plus retrieved material,
	// clearly delimited. Untrusted with respect to instructions.
	UserContent string
	// ResponseSchema, when non-nil, constrains the model to a JSON shape.
	// This is the primary control surface: a field absent from the schema
	// cannot be produced, which is how "the model may not write a
	// diagnosis" is enforced structurally instead of by asking nicely.
	ResponseSchema map[string]any
	Temperature    float32
	MaxTokens      int32
}

// GenerateResponse is the raw model output plus accounting.
type GenerateResponse struct {
	Text  string
	Usage Usage
	Model string
}

// LLM is the model surface this package needs. It exists so the router,
// the executors and the verifier can be unit-tested against a scripted
// model with no network and no credentials — the decision table in F2 is
// worth more than any single live call.
type LLM interface {
	Generate(ctx context.Context, req GenerateRequest) (GenerateResponse, error)
	Embed(ctx context.Context, text string) ([]float32, Usage, error)
}

// ErrLLMUnavailable reports that no model backend is configured. Returned
// rather than panicking so local dev and unit tests can run the whole
// service with the chat switched off.
var ErrLLMUnavailable = errors.New("chat: no LLM backend configured")

// nopLLM is the zero-value backend: every call fails cleanly. Wired when
// the service starts without a Vertex project, which is the normal state
// for local dev and for CI.
type nopLLM struct{}

func (nopLLM) Generate(context.Context, GenerateRequest) (GenerateResponse, error) {
	return GenerateResponse{}, ErrLLMUnavailable
}
func (nopLLM) Embed(context.Context, string) ([]float32, Usage, error) {
	return nil, Usage{}, ErrLLMUnavailable
}

// NopLLM returns a backend that always fails with ErrLLMUnavailable.
func NopLLM() LLM { return nopLLM{} }

// timeout bounds a single model call. The ADR budgets p95 <= 1.5 s for a
// whole turn, which includes up to three model calls; a call that has
// already blown past this has lost the turn regardless, and holding the
// request open only makes the failure slower.
const callTimeout = 20 * time.Second

// withTimeout applies callTimeout unless the caller's deadline is sooner.
func withTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	if dl, ok := ctx.Deadline(); ok && time.Until(dl) < callTimeout {
		return context.WithCancel(ctx)
	}
	return context.WithTimeout(ctx, callTimeout)
}

// wrapModelErr adds the model name to an error without leaking prompt
// content into logs.
func wrapModelErr(model string, err error) error {
	return fmt.Errorf("chat: model %s: %w", model, err)
}
