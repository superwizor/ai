-- 000082: chat_interactions — audit trail for AI assistant queries.
-- Stores every brief generation and chat Q&A with envelope-encrypted
-- content (ADR-DM-002). CASCADE from patient_files ensures RODO erasure.

CREATE TABLE chat_interactions (
    id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    therapist_id           UUID NOT NULL REFERENCES users(id),
    patient_file_id        UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    conversation_id        UUID NOT NULL,
    -- 'brief' | 'question' | 'answer' | 'summary'
    interaction_type       VARCHAR(20) NOT NULL,
    -- Envelope-encrypted content (same pattern as transcripts/reports).
    content_ciphertext     BYTEA,
    content_encrypted_dek  BYTEA,
    -- Observability: how much RAG context was used and token consumption.
    rag_hits_count         INT NOT NULL DEFAULT 0,
    model_used             VARCHAR(50) NOT NULL DEFAULT 'gemini-2.0-flash',
    input_tokens           INT NOT NULL DEFAULT 0,
    output_tokens          INT NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for loading a full conversation (multi-turn chat).
CREATE INDEX idx_chat_interactions_conversation
    ON chat_interactions(conversation_id, created_at);

-- Index for per-patient queries (RODO export, analytics).
CREATE INDEX idx_chat_interactions_patient
    ON chat_interactions(patient_file_id, created_at DESC);

-- Index for per-therapist rate limiting / quota checks.
CREATE INDEX idx_chat_interactions_therapist_daily
    ON chat_interactions(therapist_id, created_at DESC);

COMMENT ON TABLE chat_interactions IS
    'Audit trail for AI assistant interactions. Content is KMS envelope-encrypted (ADR-DM-002). Cascades from patient_files for RODO erasure.';
