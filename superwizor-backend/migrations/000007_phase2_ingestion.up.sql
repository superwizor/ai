CREATE TABLE transcripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_file_id UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    audio_gcs_uri VARCHAR(255) NOT NULL,
    transcript_ciphertext TEXT NOT NULL,
    speaker_labels JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE transcript_segments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transcript_id UUID NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,
    start_time_ms INTEGER NOT NULL,
    end_time_ms INTEGER NOT NULL,
    speaker_tag VARCHAR(50) NOT NULL,
    text_ciphertext TEXT NOT NULL
);

CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_file_id UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    transcript_id UUID NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,
    speaker_role_inference JSONB NOT NULL,
    content_ciphertext TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE hitop_measurements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    dimension VARCHAR(50) NOT NULL,
    score INTEGER NOT NULL,
    evidence TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE rag_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_file_id UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    embedding vector(768),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
