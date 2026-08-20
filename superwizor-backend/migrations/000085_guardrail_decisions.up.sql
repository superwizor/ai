-- 000085: guardrail_decisions — the evidence log for the AI chat's
-- control layer.
--
-- Spec: docs/63 F4; ADR docs/kronikarz/62 sections 7 and 9.
--
-- ══ Why this table exists ══
--
-- The chat generates new clinical information about a specific client
-- (decision D1, 2026-08-20). Article 94 of the MDR requires a
-- manufacturer to be able to demonstrate, after the fact, what the system
-- did and why. That demonstration cannot rest on application logs with a
-- 30-day retention, so it lives here: one row per turn, for 24 months.
--
-- ══ Why it holds no content ══
--
-- Not one column here contains the therapist's question, the model's
-- answer, a quote, or the classifier's rationale_short (which paraphrases
-- the question). An evidence log that reproduced the conversation would
-- be a second, less protected copy of clinical material — the opposite of
-- a safeguard. What it records is the SHAPE of every decision: which
-- intent, which route, which verdict, under which prompt versions.
--
-- ══ Retention: 24 months, EXPLICITLY OUTSIDE THE GDPR PURGER ══
--
-- The purger (clinical-svc/cmd/purger) erases patient material on a
-- 90-day cycle. If these rows were swept with it, the evidence pack would
-- evaporate three months in and the ADR's section 9 defence would have
-- nothing behind it. The exclusion is safe precisely because of the
-- previous paragraph: with no personal data in the table, there is
-- nothing for erasure to erase.
--
-- The exclusion is enforced by a NEGATIVE TEST in CI, not by this
-- comment: see clinical-svc purger tests. A comment cannot fail a build.
--
-- ══ Session identity is hashed ══
--
-- chat_session_hash is a one-way digest of the conversation ID computed
-- by the application. It lets an investigator group the turns of one
-- conversation without the table holding a key that joins back to
-- chat_interactions and, through it, to a patient file.

CREATE TABLE guardrail_decisions (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Grouping key. NOT a foreign key, deliberately: a join path to
    -- patient material is exactly what this table must not have.
    chat_session_hash     TEXT NOT NULL,

    -- ── Classification ──
    -- Label from the frozen taxonomy (pkg/guardrail): A1_SEARCH ..
    -- X_OTHER, or UNRECOGNIZED when the classifier returned garbage.
    intent                TEXT NOT NULL,
    risk_flag             BOOLEAN NOT NULL,
    -- Bucketed, never the raw score: 'very_low'|'low'|'medium'|'high'
    -- |'invalid'. The third decimal of a model's confidence invites
    -- over-reading in exactly the setting where over-reading is worst.
    confidence_bucket     TEXT NOT NULL,

    -- ── Routing ──
    -- 'answer' | 'degrade' | 'refuse'
    decision              TEXT NOT NULL,
    -- Effective intent actually served (differs from intent on degrade).
    effective_intent      TEXT NOT NULL,
    -- 'low_conf'|'defined_ops'|'quota'|'risk_flag'|'prohibited'
    -- |'out_of_scope'|'unknown_intent'|'' .
    decision_reason       TEXT NOT NULL DEFAULT '',

    -- ── Verification ──
    -- 'pass' | 'block' | 'skipped'
    verifier_result       TEXT NOT NULL,
    -- 'ungrounded'|'fabricated'|'inference'|'diag_med_risk'|'schema'
    -- |'verifier_error'|'' .
    block_reason          TEXT NOT NULL DEFAULT '',
    -- Grounding coverage: how many quotes the served response carried.
    -- A zero here on a generative intent is an alarm condition
    -- (ADR section 8.3 target: 0%).
    grounding_quote_count INT NOT NULL DEFAULT 0,

    -- ── Provenance: what the system WAS when it decided ──
    -- Without these, the log cannot answer the only question it exists
    -- to answer.
    classifier_prompt_version TEXT NOT NULL,
    verifier_prompt_version   TEXT NOT NULL DEFAULT '',
    classifier_model          TEXT NOT NULL DEFAULT '',
    generator_model           TEXT NOT NULL DEFAULT '',
    chat_mode                 TEXT NOT NULL DEFAULT '',
    -- 'web' | 'ios' | 'android'
    platform                  TEXT NOT NULL DEFAULT '',

    -- ── Cost and latency (operational, not evidential) ──
    cost_micro_usd        BIGINT NOT NULL DEFAULT 0,
    latency_ms            INT NOT NULL DEFAULT 0,

    created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Retention sweep and time-range investigation.
CREATE INDEX idx_guardrail_decisions_created
    ON guardrail_decisions(created_at DESC);

-- Threshold dashboards (ADR section 8.3): share of refusals, of
-- generative intents, of verifier blocks.
CREATE INDEX idx_guardrail_decisions_intent
    ON guardrail_decisions(intent, created_at DESC);

CREATE INDEX idx_guardrail_decisions_verifier
    ON guardrail_decisions(verifier_result, created_at DESC)
    WHERE verifier_result = 'block';

-- Reconstructing one conversation's decision sequence.
CREATE INDEX idx_guardrail_decisions_session
    ON guardrail_decisions(chat_session_hash, created_at);

COMMENT ON TABLE guardrail_decisions IS
    'MDR article 94 evidence log for the AI chat guardrail. 24-month '
    'retention. CONTAINS NO PERSONAL DATA and is DELIBERATELY EXCLUDED '
    'from the GDPR purger — see migration 000085 header and the negative '
    'test in clinical-svc. Do not add a patient_file_id, a therapist_id, '
    'or any free text derived from the conversation to this table.';

COMMENT ON COLUMN guardrail_decisions.chat_session_hash IS
    'One-way digest of the conversation ID. Not a foreign key: a join '
    'path back to patient material is what this table must not have.';

COMMENT ON COLUMN guardrail_decisions.grounding_quote_count IS
    'Quotes carried by the served response. Zero on a generative intent '
    'is an alarm condition (ADR section 8.3).';
