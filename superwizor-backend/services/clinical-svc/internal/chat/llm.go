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

// callTimeout bounds a single model call.
//
// Was 20 s, chosen on the assumption that a call exceeding it had lost
// the turn anyway. Measurement on 2026-08-20 showed that assumption was
// wrong: a real A5 generation over an 8000-character context takes 7-13 s,
// and a slow one crossed 20 s and hard-failed in front of a therapist
// ("chat turn failed"). Raised to 45 s, then to 75 s for the tail.
//
// The Flutter client must wait LONGER than this, not shorter. If it gives
// up first, the therapist sees a transport abort instead of the server's
// own message, and the turn is still billed against the quota with
// nothing to show. The client is set to 90 s — see
// flutter-app/superwizor/lib/services/grpc_client.dart, whose interceptor
// used to force 30 s onto every call and would have made this constant
// decorative.
//
// This is a ceiling for pathological cases, NOT a latency target. The
// measured breakdown of one turn is roughly:
//
//	classifier   1.6 s
//	generator    7.4 s   (at MaxTokens 2048; 12.8 s at 4096)
//	verifier     2.5 s
//	------------------
//	~11.5 s, plus retrieval and KMS
//
// The ADR budgets p95 <= 1.5 s for the whole turn. That target is not
// reachable with three sequential model calls, one of which writes
// clinical prose — streaming is what would hide it, and the verifier
// forbids streaming by design. The number needs a product decision, not
// more tuning; see docs/63 section 9.
const callTimeout = 75 * time.Second

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
