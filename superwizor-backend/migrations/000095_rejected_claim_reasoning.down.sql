ALTER TABLE report_claim_rejections
    DROP COLUMN IF EXISTS reasoning_ciphertext,
    DROP COLUMN IF EXISTS reasoning_encrypted_dek,
    DROP COLUMN IF EXISTS proposed_categories,
    DROP COLUMN IF EXISTS epistemic_status,
    DROP COLUMN IF EXISTS confidence,
    DROP COLUMN IF EXISTS evidence_span_refs;

COMMENT ON TABLE report_claim_rejections IS
    'Odrzucenia sa DANYMI, nie logiem. Progi przegladu z dok. 11 §8.3 '
    'wymagaja zapytania, a nie grepa po Cloud Logging.';
