ALTER TABLE audio_uploads DROP CONSTRAINT IF EXISTS fk_audio_uploads_session;
DROP TABLE IF EXISTS rag_memories;
DROP TABLE IF EXISTS hitop_measurements;
DROP TABLE IF EXISTS hitop_dimensions;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS transcript_segments;
DROP TABLE IF EXISTS transcripts;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS audio_uploads CASCADE;
