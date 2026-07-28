// ai_assistant.go — AI assistant handlers (GenerateSessionBrief +
// AskPatientQuestion). Uses pkg/rag for ranking and Vertex AI for
// generation.
//
// Faza 1: GenerateSessionBrief — one-shot briefing with RAG context.
// Faza 2: AskPatientQuestion — multi-turn server-streaming chat.
//
// These handlers are NOT wired into the gRPC server yet. They require:
//   1. pgxpool.Pool for RAG memory queries (pgvector cosine search)
//   2. Vertex AI generative model client (Gemini Flash)
//   3. Vertex AI embedding client (text-embedding-005, 768-dim)
//   4. cryptobox.CryptoBox for decrypting RAG memory ciphertext
//
// TODO(Krok 4): Wire these deps into Server struct + NewServer constructor
// TODO(Krok 4): Add go.mod deps: cloud.google.com/go/aiplatform
// TODO(Krok 4): Register handlers in connect_adapter.go
//
// See: docs/critical_analysis — rationale for backend-side AI.

package grpc

import (
	"context"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	"github.com/superwizor-ai/backend/pkg/rag"
)

// ── Constants ─────────────────────────────────────────────────────────

const (
	// embeddingModel is the Vertex AI embedding model used to vectorize
	// the therapist's question for RAG retrieval.
	embeddingModel = "text-embedding-005"

	// embeddingDims must match the pgvector column: vector(768).
	embeddingDims = 768

	// generativeModel is the Gemini model used for brief/chat generation.
	generativeModel = "gemini-2.0-flash"

	// generativeRegion is the Vertex AI region — europe-west4 per P3.
	generativeRegion = "europe-west4"

	// briefDefaultQuery is the embedding query when no focus_hint is given.
	briefDefaultQuery = "przygotowanie do sesji terapeutycznej, podsumowanie kluczowych wątków i wzorców"
)

// ── System Prompt ─────────────────────────────────────────────────────

const briefSystemPrompt = `Jesteś asystentem klinicznym AI dla psychoterapeuty.
Twoim zadaniem jest przygotować zwięzły briefing przed kolejną sesją terapeutyczną.

ZASADY:
- Odpowiadaj ZAWSZE po polsku, chyba że terapeuta wyraźnie poprosi o inny język.
- NIE stawiaj diagnoz. Możesz wskazywać wzorce, ale decyzje kliniczne należą do terapeuty.
- Bądź konkretny i odwołuj się do treści raportów z sesji.
- Jeśli nie masz wystarczających informacji, powiedz o tym wprost.
- NIE wymyślaj informacji, których nie ma w raportach.

FORMAT BRIEFINGU:
1. **Podsumowanie ostatniej sesji** — kluczowe wątki, emocje, dynamika
2. **Powtarzające się wzorce** — tematy, które pojawiały się w kilku sesjach
3. **Otwarte kwestie** — co zostało nierozwiązane, co wymaga uwagi
4. **Sugestie** — kierunki, pytania, techniki do rozważenia

KONTEKST SESJI:
%s`

// ── GenerateSessionBrief ──────────────────────────────────────────────

func (s *Server) GenerateSessionBrief(ctx context.Context, req *clinicalv1.GenerateSessionBriefRequest) (*clinicalv1.GenerateSessionBriefResponse, error) {
	// 1. Validate input.
	patientFileID, err := uuid.Parse(req.GetPatientFileId())
	if err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "invalid patient_file_id: %v", err)
	}

	// 2. Auth: look up patient file → verify caller owns it.
	pf, err := s.queries.GetPatientFile(ctx, patientFileID)
	if err != nil {
		return nil, status.Errorf(codes.NotFound, "patient file not found")
	}
	therapistID := uuid.UUID(pf.TherapistID.Bytes)
	if err := s.requireTherapistDataAccess(ctx, therapistID); err != nil {
		return nil, err // already a gRPC status
	}

	// 3. Generate conversation ID for audit trail and follow-up chat.
	convID := uuid.New()

	// 4. Determine query text for RAG retrieval.
	queryText := briefDefaultQuery
	if hint := strings.TrimSpace(req.GetFocusHint()); hint != "" {
		queryText = hint
	}

	slog.InfoContext(ctx, "ai_assistant.brief_requested",
		"patient_file_id", patientFileID.String(),
		"therapist_id", therapistID.String(),
		"conversation_id", convID.String(),
		"has_focus_hint", req.GetFocusHint() != "",
	)

	// ──────────────────────────────────────────────────────────
	// TODO: Wire the following steps when Vertex AI deps are added
	// to clinical-svc. The rag.SelectHits algorithm is ready in
	// pkg/rag — what's missing is:
	//   a) RAG pool loader (pgxpool query against rag_memories)
	//   b) Embedding client (Vertex AI text-embedding-005)
	//   c) Generative model client (Vertex AI Gemini Flash)
	//   d) Decrypt RAG hits (cryptobox.Decrypt)
	//   e) Persist audit row to chat_interactions
	//
	// Until wired, return Unimplemented.
	// ──────────────────────────────────────────────────────────

	_ = queryText    // will be used for embedding
	_ = therapistID  // will be used for audit
	_ = patientFileID // will be used for RAG pool query

	// Placeholder: The full flow is documented in implementation_plan.md.
	// Steps 4-9 will call:
	//   embedQuery  → generateEmbedding(ctx, queryText)
	//   pool, anchor  ← loadRAGPool(ctx, patientFileID, uuid.Nil)
	//   hits       := rag.SelectHits(pool, queryVecs, anchor, time.Now())
	//   ragContext  ← assembleContext(ctx, hits, anchor) // decrypt + format
	//   prompt     := fmt.Sprintf(briefSystemPrompt, ragContext)
	//   brief      ← gemini.GenerateContent(ctx, prompt)
	//   audit      → INSERT INTO chat_interactions(...)

	return nil, status.Errorf(codes.Unimplemented,
		"GenerateSessionBrief not yet wired — Vertex AI deps pending (see ai_assistant.go TODOs)")
}

// ── AskPatientQuestion ────────────────────────────────────────────────

func (s *Server) AskPatientQuestion(req *clinicalv1.AskPatientQuestionRequest, stream clinicalv1.ClinicalService_AskPatientQuestionServer) error {
	ctx := stream.Context()

	// 1. Validate input.
	_, err := uuid.Parse(req.GetPatientFileId())
	if err != nil {
		return status.Errorf(codes.InvalidArgument, "invalid patient_file_id: %v", err)
	}
	if strings.TrimSpace(req.GetQuestion()) == "" {
		return status.Errorf(codes.InvalidArgument, "question is required")
	}

	slog.InfoContext(ctx, "ai_assistant.question_requested",
		"patient_file_id", req.GetPatientFileId(),
		"has_conversation_id", req.GetConversationId() != "",
	)

	// TODO(Faza 2): Implement server-streaming chat.
	// This is deferred until Faza 1 (briefing) is validated.
	return status.Errorf(codes.Unimplemented,
		"AskPatientQuestion not yet implemented — Faza 2, pending briefing validation")
}

// ── RAG Helpers (to be fully implemented when Vertex AI is wired) ─────

// loadRAGPool will query rag_memories for the candidate pool.
// This mirrors llm-worker/main.go:loadRAGPool but uses the Server's
// pool/queries rather than a package-level global.
//
// Query shape (from ai-pipeline-svc):
//   WITH recent_sessions AS (
//     SELECT source_session_id, max(created_at) AS session_at
//     FROM rag_memories
//     WHERE patient_file_id = $1 AND NOT is_compacted
//       AND source_session_id IS NOT NULL
//     GROUP BY source_session_id
//     ORDER BY session_at DESC
//     LIMIT $2  -- rag.LookbackSessions (36)
//   )
//   SELECT m.id, m.source_session_id, m.chunk_type, m.created_at, m.embedding::text
//   FROM rag_memories m
//   JOIN recent_sessions rs ON rs.source_session_id = m.source_session_id
//   WHERE m.patient_file_id = $1 AND NOT m.is_compacted
//
// Returns the pool and the anchor ID (most recent summary row).
func loadRAGPoolDoc() {
	// Placeholder — documents the query for future implementation.
	// Will use s.pool.Query(ctx, ...) when pgxpool is available.
}

// parseEmbedding parses pgvector's text form "[f1,f2,...]" into []float32.
// Identical to llm-worker's version — could also be extracted to pkg/rag
// if a second consumer appears.
func parseEmbedding(s string) []float32 {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "[")
	s = strings.TrimSuffix(s, "]")
	if s == "" {
		return nil
	}
	parts := strings.Split(s, ",")
	v := make([]float32, 0, len(parts))
	for _, p := range parts {
		var f float64
		if _, err := fmt.Sscanf(strings.TrimSpace(p), "%f", &f); err != nil {
			return nil
		}
		v = append(v, float32(f))
	}
	return v
}

// Ensure rag package is used (will be used in full implementation).
var _ = rag.SelectHits
var _ = time.Now
