-- ============================================
-- AUDIO UPLOADS (krótko-żyjące, OLM 48h)
-- ============================================
CREATE TABLE audio_uploads (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    therapist_id        UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    patient_file_id     UUID NOT NULL REFERENCES patient_files(id) ON DELETE RESTRICT,
    session_id          UUID,  -- FK dodany po utworzeniu sessions

    bucket_name         VARCHAR(255) NOT NULL,
    object_path         VARCHAR(500) NOT NULL UNIQUE,
    content_type        VARCHAR(100) NOT NULL DEFAULT 'audio/m4a',
    file_size_bytes     BIGINT,
    duration_seconds    INTEGER,
    sample_rate_hz      INTEGER,
    chunk_count         INTEGER NOT NULL DEFAULT 1,

    status              upload_status NOT NULL DEFAULT 'PENDING',
    upload_started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    upload_completed_at TIMESTAMPTZ,
    expires_at          TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '48 hours'),

    -- Idempotency key dla retries
    idempotency_key     VARCHAR(128) UNIQUE,

    -- Klient meta (debug)
    client_app_version  VARCHAR(50),
    client_platform     VARCHAR(20),  -- 'ios', 'android'

    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audio_uploads_therapist ON audio_uploads(therapist_id, status);
CREATE INDEX idx_audio_uploads_session ON audio_uploads(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX idx_audio_uploads_expires ON audio_uploads(expires_at) WHERE status != 'EXPIRED';

-- ============================================
-- SESSIONS
-- ============================================
CREATE TABLE sessions (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    therapist_id                UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    patient_file_id             UUID NOT NULL REFERENCES patient_files(id) ON DELETE RESTRICT,
    audio_upload_id             UUID REFERENCES audio_uploads(id) ON DELETE SET NULL,

    session_date                DATE NOT NULL,
    session_number              INTEGER NOT NULL,
    duration_seconds            INTEGER,
    contact_form                contact_form NOT NULL DEFAULT 'OFFICE',

    -- Speaker labels mapping (zob. ADR-IMPL-002)
    speaker_label_mapping       JSONB NOT NULL DEFAULT '{}'::jsonb,

    language_code               VARCHAR(10),

    therapist_observations      TEXT,
    is_consent_confirmed        BOOLEAN NOT NULL DEFAULT FALSE,

    status                      session_status NOT NULL DEFAULT 'CREATED',
    status_updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    error_message               TEXT,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at                  TIMESTAMPTZ,

    CONSTRAINT chk_session_number_positive CHECK (session_number > 0)
);

CREATE INDEX idx_sessions_therapist_date ON sessions(therapist_id, session_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_sessions_patient_file ON sessions(patient_file_id, session_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_sessions_status ON sessions(status, status_updated_at) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_sessions_patient_file_number ON sessions(patient_file_id, session_number) WHERE deleted_at IS NULL;

-- Deferred FK from audio_uploads
ALTER TABLE audio_uploads
    ADD CONSTRAINT fk_audio_uploads_session
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE SET NULL;

-- ============================================
-- TRANSCRIPTS (blob jest kanoniczny)
-- ============================================
CREATE TABLE transcripts (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id               UUID NOT NULL REFERENCES sessions(id) ON DELETE RESTRICT,

    transcript_ciphertext    BYTEA NOT NULL,
    transcript_encrypted_dek BYTEA NOT NULL,

    language_code            VARCHAR(10) NOT NULL,
    word_count               INTEGER,
    speaker_count            INTEGER,
    confidence_avg           NUMERIC(4, 3),

    stt_model                VARCHAR(50) NOT NULL,  -- 'chirp_3'
    stt_processed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    stt_processing_seconds   INTEGER,

    blob_rebuilt_at          TIMESTAMPTZ,
    blob_rebuild_count       INTEGER NOT NULL DEFAULT 0,

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transcripts_session ON transcripts(session_id);

-- ============================================
-- TRANSCRIPT SEGMENTS (per-speaker, per-utterance)
-- ============================================
CREATE TABLE transcript_segments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transcript_id       UUID NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,

    speaker_tag         INTEGER NOT NULL,
    speaker_label       VARCHAR(50) NOT NULL,

    start_offset_ms     INTEGER NOT NULL,
    end_offset_ms       INTEGER NOT NULL,

    text_ciphertext     BYTEA NOT NULL,
    text_encrypted_dek  BYTEA NOT NULL,
    text_word_count     INTEGER,

    confidence          NUMERIC(4, 3),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transcript_segments_transcript ON transcript_segments(transcript_id, start_offset_ms);
CREATE INDEX idx_transcript_segments_speaker_tag ON transcript_segments(transcript_id, speaker_tag);

-- ============================================
-- REPORTS (LLM output)
-- ============================================
CREATE TABLE reports (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id                  UUID NOT NULL REFERENCES sessions(id) ON DELETE RESTRICT,
    transcript_id               UUID NOT NULL REFERENCES transcripts(id) ON DELETE RESTRICT,
    modality_id                 UUID NOT NULL REFERENCES modalities(id) ON DELETE RESTRICT,

    report_ciphertext           BYTEA NOT NULL,
    report_encrypted_dek        BYTEA NOT NULL,

    title                       VARCHAR(500),
    summary_short               TEXT,         
    sentiment_label             VARCHAR(50),  
    risk_level                  VARCHAR(50),  

    speaker_role_inference      JSONB NOT NULL DEFAULT '{}'::jsonb,

    llm_model                   VARCHAR(100) NOT NULL,  
    llm_input_tokens            INTEGER,
    llm_output_tokens           INTEGER,
    llm_processing_seconds      INTEGER,
    llm_total_cost_usd          NUMERIC(10, 6),

    parent_report_id            UUID REFERENCES reports(id) ON DELETE SET NULL,
    generation_count            INTEGER NOT NULL DEFAULT 1,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_reports_session ON reports(session_id);
CREATE INDEX idx_reports_modality ON reports(modality_id, created_at DESC);

-- ============================================
-- HITOP MEASUREMENTS
-- ============================================
CREATE TABLE hitop_dimensions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(50) NOT NULL UNIQUE,
    display_name    VARCHAR(255) NOT NULL,
    parent_code     VARCHAR(50),
    description     TEXT,
    level           VARCHAR(20) NOT NULL,  
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_hitop_dimensions_parent ON hitop_dimensions(parent_code);

CREATE TABLE hitop_measurements (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE RESTRICT,
    report_id           UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    dimension_id        UUID NOT NULL REFERENCES hitop_dimensions(id) ON DELETE RESTRICT,

    score               NUMERIC(5, 2) NOT NULL,
    confidence          NUMERIC(4, 3) NOT NULL,

    evidence_ciphertext BYTEA,
    evidence_encrypted_dek BYTEA,

    measured_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_score_range CHECK (score >= 0 AND score <= 100),
    CONSTRAINT chk_confidence_range CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE INDEX idx_hitop_measurements_session ON hitop_measurements(session_id);
CREATE INDEX idx_hitop_measurements_dimension ON hitop_measurements(dimension_id, measured_at DESC);
CREATE UNIQUE INDEX idx_hitop_measurements_unique ON hitop_measurements(session_id, dimension_id);

-- ============================================
-- RAG MEMORY
-- ============================================
CREATE TABLE rag_memories (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_file_id         UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    source_session_id       UUID REFERENCES sessions(id) ON DELETE SET NULL,
    source_report_id        UUID REFERENCES reports(id) ON DELETE SET NULL,

    summary_ciphertext      BYTEA NOT NULL,
    summary_encrypted_dek   BYTEA NOT NULL,

    embedding               vector(768) NOT NULL,

    chunk_type              VARCHAR(50) NOT NULL,
    importance_score        NUMERIC(4, 3) NOT NULL DEFAULT 0.5,

    is_compacted            BOOLEAN NOT NULL DEFAULT FALSE,
    compacted_into_id       UUID REFERENCES rag_memories(id) ON DELETE SET NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_accessed_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rag_memories_patient_file ON rag_memories(patient_file_id, created_at DESC) WHERE NOT is_compacted;
CREATE INDEX idx_rag_memories_embedding ON rag_memories USING hnsw (embedding vector_cosine_ops);
