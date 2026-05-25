# 13 — STT pipeline: GCS callback + server-side chunking

**Status:** design (2026-05-22). No code yet. Branch will be
`feat/stt-gcs-callback`.

**Problem statement.**

Two coupled failures in the STT pipeline today:

1. **Cloud Functions Gen2 request timeout couples to Chirp latency.** The
   `stt-worker` blocks on `op.Wait(ctx)` after submitting `BatchRecognize`.
   On 2026-05-22 we bumped `timeout_seconds = 1800` on the function (see
   `infra/modules/cloud-functions/main.tf:187`) after a 12-hour Chirp
   europe-central2 outage caused every invocation to hit the 540s ceiling.
   That patch is a band-aid: longer timeouts mean one stuck Pub/Sub message
   holds an instance for up to 30 min, and Chirp could still outlast it
   on a really bad day. Retries are re-billed BatchRecognize calls.

2. **Chirp 3 BatchRecognize hard-rejects audio > 20 min when word-level
   timestamps are enabled.** Per Google's documentation:
   > Speech.BatchRecognize (good for long audio 1 minute to 1 hour in
   > general, but **up to 20 minutes with word-level timestamp enabled**)

   We use `EnableWordTimeOffsets: true` (`stt-worker/main.go:337`) because
   our chunker (`pkg/transcription/chunker`) keys on per-word start/end
   offsets to segment by pauses ≥600ms (ADR-IMPL-007). Disabling word
   timestamps gets us 60 min but breaks pause-based chunking. Real therapy
   sessions are 45–60 minutes by design. Failure surfaced as production
   session `30e28aaf-7c87-4c63-a90e-107ab841cf1f` (log entry
   `2026-05-22T10:33:50Z`).

The two problems are independent but the fixes share infrastructure, so we
design them together and ship in two stages.

---

## Decision summary

| Stage | What | Solves | Effort |
|---|---|---|---|
| **0** (already shipped) | `CompleteAudioUpload` duration band-aid + Chirp file-level error classifier in `isTerminalSTTError` | Visible UX cliff (sessions fail with no clear message) + retry storms | 1h |
| **1** | `BatchRecognize` writes to GCS via `GcsOutputConfig`; new `stt-finalize` Cloud Function triggered by `OBJECT_FINALIZE`; revert 1800s timeout patch | Cloud Function timeout coupling, retry-and-re-bill, durable artifact for replay | 5-7d |
| **2** | Server-side chunking in `ingestion-svc.SplitAudio` (new RPC, uses existing ffmpeg in image); stt-finalize merges chunk results | 60-min sessions actually work | 7-10d |
| **3** | Remove duration band-aid; raise public limit | Lift the visible cap | <1h |

Stage 0 is in `main` as of 2026-05-20 (commit `a5e8f4c`). This doc designs
Stage 1 and Stage 2. Stage 3 is a one-line revert.

---

## Architecture — target state

```
ingestion-svc.CompleteAudioUpload
   - codec gate (Stage 0; existing)
   - if duration > 19 min: call internal SplitAudio (NEW, Stage 2)
                              → ffmpeg silencedetect + segment with 20s OVERLAP
                              → N overlapping chunk FLACs in GCS
                              → N rows in audio_chunks (storing physical start and logical seam)
   - publish audio.uploaded (unchanged shape)
       │
       ↓
Pub/Sub audio.uploaded
       │
       ↓
┌──────────────────────────────────────────────────────────────────┐
│ stt-submit (renamed stt-worker; same Cloud Function Gen2 binary  │
│ as today, refactored. Same entry point `ProcessAudio`.)          │
│                                                                  │
│  1. SELECT sessions.status FOR UPDATE SKIP LOCKED                │
│  2. UPDATE sessions.status = 'TRANSCRIBING'                      │
│  3. resolve language + diarization config (existing)             │
│  4. Read audio_chunks rows for this audio_upload (Stage 2) OR    │
│     fabricate a single virtual chunk (Stage 1 / short audio).    │
│  5. Query existing successfully submitted stt_operations rows    │
│     to skip already-submitted chunks (fixes retry-trap).         │
│  6. For each non-submitted chunk:                                │
│     - Submit BatchRecognize with GcsOutputConfig pointing at     │
│       gs://<project>-transcripts-raw/{session_id}/chunk_{i}/     │
│     - INSERT into stt_operations                                 │
│  7. ack Pub/Sub (return nil)                       <5s typical   │
└──────────────────────────────────────────────────────────────────┘
       │
       │ Chirp processes async (1-30 min total for 60-min session)
       │
       ↓
gs://<project>-transcripts-raw/{session_id}/chunk_{i}/transcript_*.json
       │
       │ OBJECT_FINALIZE Eventarc trigger (per file)
       │
       ↓
┌──────────────────────────────────────────────────────────────────┐
│ stt-finalize (NEW Cloud Function Gen2; cmd/stt-finalize/main.go) │
│                                                                  │
│  1. Parse GCS object path → (session_id, chunk_index)            │
│     Ignore metadata sidecar files (ParseOutputObjectPath filter) │
│  2. Idempotent UPDATE stt_operations SET finalized_at = now()    │
│     WHERE (session_id, chunk_index) = (...)                      │
│     AND finalized_at IS NULL                                     │
│  3. SELECT COUNT(*) WHERE session_id = ? AND finalized_at IS NULL│
│     If > 0 → return nil (other chunks pending)                   │
│  4. ALL chunks finalized → "merger" path:                        │
│     a. SELECT status FROM sessions WHERE id=? FOR UPDATE         │
│        - if status != TRANSCRIBING → ack (already merged / fail) │
│        - else UPDATE status = 'MERGING'                          │
│     b. For each chunk_index in order:                            │
│        - download GCS object                                     │
│        - ParseChirp3Results (existing function, unchanged)       │
│        - If chunk_index > 0 AND native diarization on:           │
│          time-anchor-match words across the overlap window,      │
│          build co-occurrence matrix of speaker labels, derive    │
│          translation map, apply to current chunk's labels, then  │
│          discard duplicate words inside the overlap. Falls back  │
│          to label-by-ordinal offset when match count is below    │
│          threshold. Language-agnostic (script-independent).      │
│        - re-relativize remaining words by chunk.start_offset_ms  │
│        - append to []Word                                        │
│     c. chunker.ChunkByPauses(words) (existing)                   │
│     d. persistTranscript (existing) — single transcripts row     │
│        - Handle unique constraint to support crash-recovery.     │
│     e. updateSessionStatus = 'ANALYZING'                         │
│     f. publishTranscriptCompleted                                │
│     * If merge fails, reset status to 'TRANSCRIBING' (fixes lock)│
│  5. ack Pub/Sub                                                  │
└──────────────────────────────────────────────────────────────────┘
       │
       ↓
Pub/Sub transcript.completed
       │
       ↓
llm-worker (UNCHANGED)
```

**What changes externally:** nothing. The `transcript.completed` event has
the same shape (`session_id`, `transcript_id`). `llm-worker`,
`notification-svc`, the Flutter app, none of them notice.

**What changes internally:** stt processing splits into submit + finalize.
A new GCS bucket holds intermediate Chirp output. Multiple chunks fan out
through Chirp in parallel and fan back in at finalize.

---

## Stage 1 — GCS callback, single-chunk only

Ships the submit/finalize split with `chunk_count=1` for every session.
Sessions > 20 min still fail (Chirp rejects on submit; the rejection lands
in GCS as an error file; finalize marks session FAILED). Same outcome as
today, but ~5s instead of 30s, and zero re-bills.

### Data model

New migration `migrations/000021_stt_operations.up.sql`:

```sql
CREATE TABLE stt_operations (
    -- One row per BatchRecognize submission. Stage 1: always
    -- one row per session (chunk_index = 0). Stage 2:
    -- multiple rows when audio > 19 min was split server-side.
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

    -- Index in the chunk sequence for this session. 0 means
    -- "the only chunk" in Stage 1. UNIQUE prevents the
    -- redelivery race (same chunk submitted twice).
    chunk_index     INT  NOT NULL DEFAULT 0,
    -- Total chunks expected for this session. stt-finalize uses
    -- COUNT(*) WHERE finalized_at IS NULL but also needs the
    -- denominator to be sure all rows landed (a row might be
    -- missing from a failed submit). Set at submit time.
    chunk_count     INT  NOT NULL DEFAULT 1,

    -- Offset of THIS chunk's start in the ORIGINAL audio's
    -- timeline. Used by stt-finalize to re-relativize per-chunk
    -- word offsets when merging. Stage 1: always 0.
    start_offset_ms BIGINT NOT NULL DEFAULT 0,

    -- Chirp operation handle. Useful for the watchdog (poll the
    -- Operations API when finalize hasn't fired in 30 min).
    operation_id    TEXT NOT NULL,
    -- gs://bucket/path/ prefix where Chirp wrote the result file.
    gcs_output_uri  TEXT NOT NULL,

    -- Submit-time config snapshot. stt-finalize trusts these
    -- over re-reading env vars (which might have flipped
    -- between submit and finalize).
    language_code            TEXT NOT NULL DEFAULT '',
    used_native_diarization  BOOLEAN NOT NULL DEFAULT FALSE,

    submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    finalized_at    TIMESTAMPTZ,
    -- If finalize classified the result as terminal failure
    -- (e.g. Chirp file-level error), the reason ends up here
    -- for ops inspection. NULL on success.
    finalize_error  TEXT,

    UNIQUE (session_id, chunk_index)
);

-- Watchdog query: WHERE submitted_at < now() - interval '30 minutes'
-- AND finalized_at IS NULL.
CREATE INDEX idx_stt_operations_pending
    ON stt_operations(submitted_at)
    WHERE finalized_at IS NULL;
```

Note `(session_id, chunk_index)` is `UNIQUE` but not `PRIMARY KEY` — we
keep a synthetic `id` for foreign-key targets and ON DELETE CASCADE
through `sessions(id)`. This is the same pattern used by `transcripts` and
`transcript_segments` per the data-model conventions.

### Files to add / modify

| Path | Change |
|---|---|
| `migrations/000021_stt_operations.up.sql` + `.down.sql` | NEW (above). |
| `services/ai-pipeline-svc/cmd/stt-worker/main.go` | Refactored. `ProcessAudio` now submits + writes `stt_operations`, returns immediately. Helper functions for chunked input (Stage 2). |
| `services/ai-pipeline-svc/cmd/stt-finalize/main.go` | NEW. Cloud Function entry `ProcessTranscriptObject`. Idempotent finalize logic. |
| `services/ai-pipeline-svc/cmd/stt-finalize/main_test.go` | NEW. Unit tests for path parsing, idempotent finalize, merge ordering. |
| `services/ai-pipeline-svc/internal/sttgcs/` | NEW package. `ParseOutputObjectPath`, `MergeChirpResults`, fixture loader. Pure logic, no GCS/DB deps. |
| `infra/modules/cloud-functions/main.tf` | Add `stt_finalize` resource. Revert `stt_worker.timeout_seconds` from 1800 → 120. Add `transcripts_raw_bucket` resource. |
| `infra/modules/cloud-functions/package.sh` | Add `stt-finalize` packaging block (copy `cmd/stt-finalize` + same deps as stt-worker). |
| `infra/modules/storage/main.tf` (or new sub-module) | New CMEK-encrypted bucket with OLM 7d. |
| `services/ai-pipeline-svc/cmd/stt-watchdog/main.go` | NEW. Cloud Scheduler-invoked HTTP function. Polls stt_operations pending > 30 min. |
| `services/ai-pipeline-svc/cmd/stt-align-eval/` | NEW (Stage 2 prerequisite). Offline eval harness for the cross-chunk alignment algorithm. Required to gate every language flip in `Chirp3DiarizationLanguages`. See Tests section. |
| `services/ai-pipeline-svc/internal/sttgcs/alignment.go` | NEW (Stage 2). Time-anchored matching + co-occurrence-based label translation + degenerate-case decision table. Pure logic, fixture-tested. Constants tunable via `align*` named constants. |

### stt-submit flow (refactored ProcessAudio)

```go
func ProcessAudio(ctx context.Context, e event.Event) error {
    // 1-3. Decode event, dedupe poison redeliveries, load session
    //      language, diarization gate. (UNCHANGED from today.)

    // 4. Build chunk list. Stage 1: always one chunk covering the
    //    whole upload. Stage 2: read audio_chunks rows.
    chunks, err := loadChunkPlan(ctx, audioUploadID)
    if err != nil {
        return handleSTTError(ctx, logger, sessionID, err)
    }

    // 5. UPDATE sessions.status = TRANSCRIBING (existing).

    // 6. Fetch already submitted chunks for this session to avoid the partial-submission retry trap.
    existingOps, err := loadSubmittedOperations(ctx, sessionID)
    if err != nil {
        return handleSTTError(ctx, logger, sessionID, err)
    }
    submitted := make(map[int]bool)
    for _, op := range existingOps {
        submitted[op.ChunkIndex] = true
    }

    // 7. For each chunk: submit BatchRecognize + record if not already submitted.
    for _, ch := range chunks {
        if submitted[ch.ChunkIndex] {
            logger.Info("chunk already submitted, skipping", "chunk_index", ch.ChunkIndex)
            continue
        }

        opID, gcsOut, err := submitBatchRecognize(ctx, submitParams{
            gcsURI:              ch.GCSUri,
            languageCode:        bcp47Lang,
            useNativeDiarization: useNativeDiarization,
            outputPrefix:         outputPrefixFor(sessionID, ch.ChunkIndex),
        })
        if err != nil {
            // Submit failures are usually quota / IAM / 5xx. Return err for Pub/Sub retry.
            // Already-submitted chunks are safely skipped on the next retry.
            return handleSTTError(ctx, logger, sessionID, err)
        }

        if err := insertSTTOperation(ctx, sttOpParams{
            SessionID:               sessionID,
            ChunkIndex:              ch.ChunkIndex,
            ChunkCount:              len(chunks),
            StartOffsetMS:           ch.StartOffsetMS,
            OperationID:             opID,
            GCSOutputURI:            gcsOut,
            LanguageCode:            bcp47Lang,
            UsedNativeDiarization:   useNativeDiarization,
        }); err != nil {
            // Race on (session_id, chunk_index) UNIQUE. Other worker won the submit.
            // Log and continue to ensure remaining chunks are submitted.
            if isUniqueViolation(err) {
                logger.Warn("redelivery race; another worker submitted chunk",
                    "chunk_index", ch.ChunkIndex)
                continue
            }
            return handleSTTError(ctx, logger, sessionID, err)
        }
    }

    // 8. Ack Pub/Sub. Total time: ~5s typical.
    return nil
}
```

### `BatchRecognize` request shape

```go
req := &speechpb.BatchRecognizeRequest{
    Recognizer: fmt.Sprintf("projects/%s/locations/eu/recognizers/_", projectID),
    Config: &speechpb.RecognitionConfig{
        // ... same as today (DecodingConfig, Model=chirp_3, LanguageCodes, Features) ...
    },
    Files: []*speechpb.BatchRecognizeFileMetadata{
        {AudioSource: &speechpb.BatchRecognizeFileMetadata_Uri{Uri: gcsURI}},
    },
    // CHANGED: GcsOutputConfig instead of InlineOutputConfig.
    RecognitionOutputConfig: &speechpb.RecognitionOutputConfig{
        Output: &speechpb.RecognitionOutputConfig_GcsOutputConfig{
            GcsOutputConfig: &speechpb.GcsOutputConfig{
                Uri: outputPrefix, // gs://bucket/{sid}/chunk_{i}/
            },
        },
    },
}

op, err := speechClient.BatchRecognize(ctx, req)
if err != nil {
    return "", "", err // submit failure — see handler
}

return op.Name(), outputPrefix, nil
// No op.Wait(ctx). Chirp will write to GCS when done.
```

### stt-finalize handler

```go
// ProcessTranscriptObject is the Cloud Function entry point.
// Eventarc trigger: OBJECT_FINALIZE on the transcripts-raw bucket.
// Filter: only files matching {session_id}/chunk_{i}/transcript_*.json
// — the bucket holds nothing else but we filter anyway because Chirp
// writes a sidecar metadata file too in some configurations.
func ProcessTranscriptObject(ctx context.Context, e event.Event) error {
    obj, err := decodeStorageObjectEvent(e)
    if err != nil {
        return nil // malformed event; not retryable
    }

    parsed, ok := sttgcs.ParseOutputObjectPath(obj.Name)
    if !ok {
        logger.Info("skipping non-transcript object", "name", obj.Name)
        return nil
    }
    sessionID, chunkIndex := parsed.SessionID, parsed.ChunkIndex

    // 1. Idempotent finalized_at write. UNIQUE on (session_id, chunk_index)
    //    plus the IS NULL guard means re-deliveries are no-ops.
    res, err := dbPool.Exec(ctx, `
        UPDATE stt_operations
        SET finalized_at = now()
        WHERE session_id = $1 AND chunk_index = $2 AND finalized_at IS NULL`,
        sessionID, chunkIndex)
    if err != nil {
        return err // transient DB; Pub/Sub retries
    }
    if res.RowsAffected() == 0 {
        // Already finalized by another invocation. Ack.
        return nil
    }

    // 2. Are we the merger? Count pending; if zero, race for the merge lock.
    return finalizeIfReady(ctx, sessionID)
}

func finalizeIfReady(ctx context.Context, sessionID uuid.UUID) error {
    tx, err := dbPool.Begin(ctx)
    if err != nil {
        return err
    }
    defer tx.Rollback(ctx)

    var pending int
    err = tx.QueryRow(ctx, `
        SELECT COUNT(*) FROM stt_operations
        WHERE session_id = $1 AND finalized_at IS NULL`,
        sessionID).Scan(&pending)
    if err != nil {
        return err
    }
    if pending > 0 {
        return nil // still waiting on sibling chunks
    }

    // All chunks finalized. Acquire the merge lock by checking-and-flipping
    // sessions.status. FOR UPDATE serializes concurrent finalize attempts
    // (Pub/Sub at-least-once could deliver two events for the same chunk
    // racing the count above).
    var status string
    err = tx.QueryRow(ctx,
        "SELECT status FROM sessions WHERE id = $1 FOR UPDATE",
        sessionID).Scan(&status)
    if err != nil {
        return err
    }
    if status != "TRANSCRIBING" {
        // Already merged (status=ANALYZING/COMPLETED) or already
        // failed (FAILED). Ack — someone else handled the merge.
        return nil
    }
    _, err = tx.Exec(ctx,
        "UPDATE sessions SET status = 'MERGING' WHERE id = $1",
        sessionID)
    if err != nil {
        return err
    }
    if err := tx.Commit(ctx); err != nil {
        return err
    }

    // Lock acquired. Do the merge work outside the transaction
    // (downloads, decrypts, chunker run can each take many seconds).
    return mergeAndPersist(ctx, sessionID)
}
```

### `mergeAndPersist` (the work itself)

1. `SELECT * FROM stt_operations WHERE session_id = $1 ORDER BY chunk_index`.
2. For each row:
   - GCS read at `gcs_output_uri` (find the `transcript_*.json` file).
   - `json.Unmarshal` into `speechpb.BatchRecognizeResponse` (proto JSON).
   - **Check file-level errors.** Same pattern as today's
     `ParseChirp3Results`. If any chunk has a per-file Error:
     - Log; classify via `isTerminalSTTError`.
     - If terminal: `updateSessionStatus(sessionID, "FAILED")`, write the
       error message into `stt_operations.finalize_error` for the failing
       chunk, return nil.
     - If transient: return err for Pub/Sub retry.
   - Call `ParseChirp3Results(resp, useNativeDiarization, langCode)` on the successful path.
   - **Cross-chunk diarization alignment (Stage 2; only when `chunk_index > 0` AND `used_native_diarization = TRUE`):**

     **Primary signal: time anchors.** Chirp's word-level timestamps are stable across calls to within ~100–200ms even though word boundaries / casing / punctuation can drift. The algorithm matches words across the overlap window by absolute timestamp, with text edit distance as a tie-breaker:

     1. Compute the overlap window in absolute milliseconds: `[chunk.start_offset_ms, prior_chunk.seam_offset_ms]`.
     2. Pull prior chunk's words whose absolute `StartMS` falls inside the window → `W_prev`.
     3. Pull current chunk's local words whose `(StartMS + chunk.start_offset_ms)` falls inside the window → `W_curr`.
     4. For each `w_curr ∈ W_curr`: find all `w_prev ∈ W_prev` with `|w_prev.StartMS - (w_curr.StartMS + chunk.start_offset_ms)| ≤ alignTimeMatchToleranceMS`.
        - Exactly 1 candidate → pair them, record `(w_prev.SpeakerLabel, w_curr.SpeakerLabel)` in the co-occurrence matrix.
        - Multiple candidates → pick the one with highest text-similarity ratio (Levenshtein-based, ≥ `alignTextSimilarityRatio` to count). If still tied, skip.
        - Zero candidates → skip `w_curr` (silence / drift; no signal to extract).
     5. Build the translation map: for each current-chunk label `L_curr`, the most common `L_prev` it co-occurred with — gated on `alignMajorityFraction` (e.g. ≥60% of `L_curr`'s co-occurrences must agree).
     6. Apply the translation map to **all** of the current chunk's words. Then discard current-chunk words whose absolute `StartMS` falls inside the overlap window (de-duplication).
     7. Re-relativize remaining current-chunk words by adding `chunk.start_offset_ms` to local `StartMS`/`EndMS`; append to the master `[]Word`.

     **Why time-anchored matching (not text-anchored) is the primary signal**: it's script-agnostic. Word-level edit distance works for Latin/Cyrillic scripts but breaks on CJK (Chinese/Japanese/Korean) where Chirp returns character-level segments with no consistent space-delimited "words". Time anchors are universal — they work for every language Chirp 3 supports.

     **Degenerate cases — explicit decision table:**

     | Condition | Behavior |
     |---|---|
     | Matched pairs ≥ `alignMinMatchedPairs` AND no ambiguous labels in the translation map | Apply translation; discard duplicate words in overlap. **Happy path.** |
     | Matched pairs ≥ `alignMinMatchedPairs` BUT some current-chunk labels are ambiguous (no `alignMajorityFraction` majority) | Apply the unambiguous mappings; ambiguous current-chunk labels keep their original value AND get offset into a non-colliding range (`prevMaxLabel + k`). Downstream LLM diarization re-clusters by content. |
     | Matched pairs < `alignMinMatchedPairs` (silence-heavy overlap, transcription drift, or one chunk's diarization is empty) | **Fall back to label-by-ordinal offset.** Rewrite Chunk i's label "1" → `prevMaxLabel + 1`, "2" → `prevMaxLabel + 2`, etc. Preserves intra-chunk speaker fidelity; loses cross-chunk continuity. The LLM call-1 role-only path sees `N+M` speakers and re-clusters them by content. Emit `stt_cross_chunk_alignment_fallback` log + metric. |
     | Current chunk has labels not present in the overlap region (new speaker entered after the seam) | Always assign new global labels — `prevMaxLabel + k`. Same as the fallback path for those labels specifically. |
     | Current chunk's diarization is completely empty (Chirp returned no labels at all) | Skip alignment; concat words with empty `SpeakerLabel`. Downstream LLM clustering handles. |
     | Native diarization is OFF for this language (`Chirp3DiarizationLanguages[lang] == false`) | Skip alignment entirely; words have no `SpeakerLabel` from Chirp anyway. |

     **Algorithm parameters (named constants in `services/ai-pipeline-svc/internal/sttgcs/alignment.go`):**

     ```go
     const (
         // Max time gap (ms) between two words across chunk boundaries
         // to consider them the same utterance for co-occurrence purposes.
         // Empirically tuned via the eval harness; expect 100–250ms.
         alignTimeMatchToleranceMS = 200

         // When multiple prior-chunk words fall inside the time tolerance
         // of one current-chunk word, pick the one with highest text
         // similarity. Below this ratio (Levenshtein over max-length),
         // even the best text match is rejected and we skip the word.
         alignTextSimilarityRatio = 0.7

         // Minimum matched-pair count to trust the translation map.
         // Below this we fall back to label-by-ordinal.
         alignMinMatchedPairs = 10

         // For each current-chunk label, the fraction of co-occurrences
         // that must agree on a single prior-chunk label to accept the
         // translation. Below this the label is "ambiguous" and gets
         // offset into a non-colliding range.
         alignMajorityFraction = 0.6

         // ingestion-svc extends the physical overlap until at least
         // this many candidate matched-pairs (approximated by spoken-
         // word count in the prior chunk's overlap tail) are available,
         // capped at alignOverlapCapMS.
         alignTargetMatchedPairs = 30

         // Hard cap on overlap duration regardless of word density.
         alignOverlapCapMS = 45_000  // 45s
         alignOverlapMinMS = 10_000  // 10s
     )
     ```

     **Function contract for `AlignAndMapSpeakers`:**

     ```go
     // AlignAndMapSpeakers builds a co-occurrence map of speaker labels
     // across two adjacent chunks' overlap window using time-anchored
     // matching with text similarity as a tie-breaker. Returns the
     // current chunk's words with their SpeakerLabel rewritten to the
     // prior chunk's labeling space, plus a fallback flag for
     // observability.
     //
     //   priorWords:        prior chunk's words, ABSOLUTE TIME.
     //   currLocalWords:    current chunk's words, LOCAL TIME.
     //   currStartOffsetMS: chunk_i.start_offset_ms
     //   priorSeamMS:       chunk_{i-1}.seam_offset_ms
     //   prevMaxLabel:      highest numeric label seen so far across
     //                      previously-merged chunks (for offset
     //                      collision avoidance in fallback paths).
     //
     // Returns:
     //   mappedWords:  currLocalWords with SpeakerLabel rewritten;
     //                 LOCAL TIME (caller re-relativizes).
     //   newMaxLabel:  highest numeric label after mapping (the next
     //                 chunk's prevMaxLabel input).
     //   fellBack:     true when the algorithm fell back to label-by-
     //                 ordinal offset because the overlap was too sparse.
     func AlignAndMapSpeakers(
         priorWords, currLocalWords []chunker.Word,
         currStartOffsetMS, priorSeamMS int64,
         prevMaxLabel int,
     ) (mappedWords []chunker.Word, newMaxLabel int, fellBack bool)
     ```
3. `chunker.ChunkByPauses(words, chunker.DefaultConfig())`.
4. `persistTranscript(ctx, sessionID, mergedResult, chunks, totalProcessingTime)`.
   - On UNIQUE constraint violation (`23505` on `transcripts(session_id)`), treat it as a prior successful attempt that crashed post-commit. Fetch the existing transcript row's `id` and proceed to step 5 (skip the insert, continue with status update + publish).
5. `updateSessionStatus(ctx, sessionID, "ANALYZING")`.
6. `publishTranscriptCompleted(ctx, sessionID, transcriptID)`.
7. **Robust failure handling.** Wrap the entire `mergeAndPersist` body in a deferred handler that branches on terminal vs. transient:

   ```go
   defer func() {
       if rerr == nil { return }
       if isTerminalSTTError(rerr) {
           _ = updateSessionStatus(ctx, sessionID, "FAILED")
       } else {
           // Transient (DB, KMS, GCS 5xx) — release the merge lock so
           // a retry can pick up the work. Without this, the session
           // stays in MERGING forever and the status guard at
           // finalizeIfReady entry never lets another worker re-enter.
           _ = updateSessionStatus(ctx, sessionID, "TRANSCRIBING")
       }
   }()
   ```

   The terminal branch covers Chirp file-level errors that surface during the per-chunk parse (e.g. a chunk that came back with `"is too long"` because Stage 2's chunker buggily produced an oversized segment). Without the split, transient failures would loop to `TRANSCRIBING` and terminal failures would loop forever.

8. **Observability.** When the alignment falls back to label-by-ordinal offset (the `fellBack = true` path), emit:
   - Structured log: `slog.Warn("stt_cross_chunk_alignment_fallback", "session_id", ..., "chunk_index", ..., "matched_pairs", ...)`.
   - Cloud Monitoring custom metric: `stt_cross_chunk_alignment_fallback_count` (per language label). Set an alert on rolling 24h fallback rate > 5% — that's the canary for "alignment algorithm degrading in production."

### Word-offset re-relativization + merge

```go
// MergeChirpResults takes one Chirp response per chunk plus the
// chunk's start and logical seam offsets in the original audio,
// aligns the overlapping zones to translate independent native-
// diarization speaker labels (time-anchored matching, language-
// agnostic), discards duplicate overlap words, and emits a single
// []chunker.Word with offsets in the original audio's timeline.
// Pure function; tested via fixtures. Lives in internal/sttgcs.
func MergeChirpResults(parts []ChunkResult) ([]chunker.Word, *TranscriptResult, MergeStats) {
    merged := make([]chunker.Word, 0)
    var stats MergeStats
    languageCode := ""
    speakerSet := map[string]bool{}
    prevMaxLabel := 0 // highest numeric SpeakerLabel committed to `merged` so far

    // priorAbsWords holds the IMMEDIATELY PRIOR chunk's words rewritten
    // into absolute time AND post-alignment labeling space. The next
    // iteration's AlignAndMapSpeakers uses ONLY this slice (not the
    // whole merged stream) so alignment runtime stays O(overlap_size),
    // not O(N²).
    var priorAbsWords []chunker.Word
    var priorSeamMS int64 // chunk_{i-1}.seam_offset_ms

    for i, p := range parts {
        // 1. Pull chunk's local-time words out of Chirp's response.
        localWords := chirpWordsToChunkerWords(p.Result.Words)

        // 2. Map labels against prior chunk (chunk 0: no alignment).
        var mapped []chunker.Word
        var fellBack bool
        if i == 0 || !p.UsedNativeDiarization {
            mapped = localWords
        } else {
            mapped, prevMaxLabel, fellBack = AlignAndMapSpeakers(
                priorAbsWords, localWords,
                p.StartOffsetMS, priorSeamMS,
                prevMaxLabel,
            )
            if fellBack {
                stats.FallbackCount++
            }
        }

        // 3. Deduplicate: discard words whose ABSOLUTE start falls in
        //    the overlap window with the prior chunk. (Chunk 0 has
        //    no prior, so no overlap to drop.)
        overlapAbsEnd := priorSeamMS
        kept := make([]chunker.Word, 0, len(mapped))
        for _, w := range mapped {
            absStart := w.StartMS + p.StartOffsetMS
            if i > 0 && absStart < overlapAbsEnd {
                continue // duplicate from prior chunk's tail
            }
            kept = append(kept, w)
        }

        // 4. Re-relativize to absolute time and append.
        absChunkWords := make([]chunker.Word, 0, len(kept))
        for _, w := range kept {
            abs := chunker.Word{
                Text:         w.Text,
                StartMS:      w.StartMS + p.StartOffsetMS,
                EndMS:        w.EndMS + p.StartOffsetMS,
                Confidence:   w.Confidence,
                SpeakerLabel: w.SpeakerLabel,
            }
            absChunkWords = append(absChunkWords, abs)
            if w.SpeakerLabel != "" {
                speakerSet[w.SpeakerLabel] = true
            }
        }
        merged = append(merged, absChunkWords...)
        stats.TotalWordCount += len(absChunkWords)
        stats.TotalConfidence += sumConfidence(absChunkWords)
        if languageCode == "" {
            languageCode = p.Result.LanguageCode
        }

        // 5. Advance the rolling state — ONLY this chunk's words,
        //    not the cumulative `merged`. This is the key fix vs.
        //    the v1 sketch which had `priorWords = merged` (O(N²)
        //    alignment search space + semantic bug).
        priorAbsWords = absChunkWords
        priorSeamMS = p.SeamOffsetMS
    }

    summary := &TranscriptResult{
        WordCount:            stats.TotalWordCount,
        SpeakerCount:         len(speakerSet),
        LanguageCode:         languageCode,
        ConfidenceAvg:        stats.AverageConfidence(),
        HasNativeDiarization: parts[0].UsedNativeDiarization,
    }
    return merged, summary, stats
}

// MergeStats is returned from MergeChirpResults so the caller
// (mergeAndPersist) can emit the cross-chunk fallback metric to
// Cloud Monitoring without inspecting per-word state.
type MergeStats struct {
    TotalWordCount    int
    TotalConfidence   float32
    ConfidenceWords   int
    FallbackCount     int // # of seams that fell back to ordinal-offset
}
```

### Terraform — new bucket

```hcl
# infra/modules/storage/transcripts_raw.tf (new file in existing module)
resource "google_storage_bucket" "transcripts_raw" {
  name                        = "${var.project_id}-transcripts-raw"
  project                     = var.project_id
  location                    = var.region # europe-central2
  uniform_bucket_level_access = true
  force_destroy               = false

  # PHI lives here briefly (Chirp output contains transcript text).
  # Same KMS key as audio_uploads + transcripts DB column (ADR-DM-002).
  encryption {
    default_kms_key_name = var.app_data_key_id
  }

  lifecycle_rule {
    action { type = "Delete" }
    # 7 days is generous; we only need it long enough for stt-finalize
    # to run (~minutes). 7d gives a weekend to debug. Don't extend
    # past 30d — PHI residence policy.
    condition { age = 7 }
  }

  versioning { enabled = false }
}

# IAM:
# - stt-worker SA: storage.objectCreator (writes Chirp output target)
# - stt-finalize SA (same SA reused): storage.objectViewer
# - Speech-to-Text service agent: storage.objectAdmin (Chirp writes
#   on behalf of the user calling the API)
# - Eventarc service agent: pubsub.publisher on the auto-created
#   Pub/Sub topic backing OBJECT_FINALIZE.
```

### Terraform — new function

```hcl
# infra/modules/cloud-functions/main.tf — add after llm_worker block
resource "google_cloudfunctions2_function" "stt_finalize" {
  name        = "stt-finalize"
  location    = var.region
  project     = var.project_id
  description = "Reads Chirp output from GCS, runs chunker, persists transcript"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessTranscriptObject"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.stt_finalize_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "1Gi"
    available_cpu         = "1"
    # Finalize work: GCS download (~few MB) + JSON unmarshal +
    # ParseChirp3Results + chunker + persistTranscript +
    # publishTranscriptCompleted. Total ~30s p99 for a 60-min session.
    timeout_seconds       = 120
    service_account_email = var.stt_worker_sa_email # reuse the same SA

    environment_variables = {
      GCP_PROJECT_ID    = var.project_id
      KMS_KEY_URI       = var.app_data_key_id
      AUDIO_BUCKET_NAME = var.audio_bucket_name
    }

    secret_environment_variables {
      key        = "DATABASE_URL"
      project_id = var.project_id
      secret     = var.db_url_secret_id
      version    = "latest"
    }

    vpc_connector                 = var.vpc_connector_id
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.storage.object.v1.finalized"
    event_filters {
      attribute = "bucket"
      value     = var.transcripts_raw_bucket_name
    }
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.stt_worker_sa_email
  }

  depends_on = [
    google_project_iam_member.stt_worker_eventarc,
    google_project_iam_member.stt_worker_sql,
    google_kms_crypto_key_iam_member.stt_worker_kms,
  ]
}

# And revert the 1800s patch on stt_worker.timeout_seconds → 120.
```

### Watchdog

`services/ai-pipeline-svc/cmd/stt-watchdog/main.go` — HTTP-triggered Cloud
Function invoked by Cloud Scheduler every 15 min:

```go
// ProcessWatchdog scans for stuck submits. For each:
//   - Poll Chirp Operations API.
//   - If DONE: drive finalize manually (read GCS output, run
//     ProcessTranscriptObject equivalent inline). This catches the
//     "Eventarc dropped the event" case.
//   - If ERROR: mark session FAILED, set finalize_error.
//   - If PENDING: leave alone. Log for visibility.
// Idempotent — does nothing on rows that finalized between query
// and processing.
```

Cron: `*/15 * * * *`. Cloud Scheduler resource added to terraform.

---

## Stage 2 — server-side chunking

Adds the > 20-min capability. Builds on the Stage 1 infrastructure
(stt_operations table, stt-finalize function, GCS callback). The merge
path in stt-finalize is unchanged; what changes is:

1. **ingestion-svc** learns to split long uploads via ffmpeg before
   publishing `audio.uploaded`.
2. **stt-submit** learns to read `audio_chunks` and submit one
   BatchRecognize per chunk in a single invocation.

### Why ingestion-svc owns the split (not stt-submit)

- ffmpeg is already in the ingestion-svc Docker image (added 2026-05-20
  for the iPhone ConvertAudio flow).
- stt-worker is Cloud Functions Gen2 → Google buildpack runtime → can't
  add native binaries cleanly.
- Splitting before `audio.uploaded` keeps the worker code simple. The
  worker reads a fan-out it didn't have to compute.

### New ingestion-svc internals

**ConvertAudio extended (preferred)** — `IngestionService.ConvertAudio` is
already idempotent for already-Chirp-supported codecs. Extend it to also
chunk long FLAC inputs:

```proto
// ingestion.proto
message ConvertAudioRequest {
    string audio_upload_id = 1;
    string target_content_type = 2;
    // NEW (Stage 2): if true, also chunk the result into ≤
    // max_chunk_seconds segments. Default false preserves Stage 1
    // semantics (single output).
    bool   chunk_for_chirp = 3;
    // NEW: max chunk length. Default 1140 (19 minutes) when
    // chunk_for_chirp=true and this field is 0. Bounded server-
    // side at 1200 (Chirp's hard limit minus safety margin).
    int32  max_chunk_seconds = 4;
}
```

**Alternative: separate RPC** — `SplitAudio(audio_upload_id, max_seconds)`.
Cleaner separation but adds a method to maintain. Recommendation: extend
ConvertAudio; the codec normalization and the chunking are both
preparing-for-Chirp work and naturally co-located.

### ffmpeg chunking strategy

Use `silencedetect` to find silence boundaries near the target chunk
length, then `-ss` + `-t` segment cuts. Two passes:

```
# Pass 1: scan for silences ≥ 200ms below -30dB.
ffmpeg -i input.flac -af silencedetect=noise=-30dB:d=0.2 -f null - 2>silences.txt

# Pass 2: for each target boundary (e.g., 18:00, 36:00, 54:00 for
# a 70-min file), find the nearest detected silence and use its
# midpoint as the cut. Then:
ffmpeg -i input.flac -ss 0 -t 1080 -c:a flac -compression_level 5 chunk_0.flac
ffmpeg -i input.flac -ss 1080 -t 1080 -c:a flac -compression_level 5 chunk_1.flac
# (-ss/-t in seconds; actual times come from silence-detect)
```

Why cut on silence and not naive time-based cuts:

- The pause-based chunker in `pkg/transcription/chunker` keys on inter-word
  gaps ≥ 600ms. Cutting mid-word would (a) destroy the word in Chirp's
  output, and (b) the gap created by re-assembly might artifically look
  like a 600ms pause and create a spurious chunk boundary at the seam.
- Cutting on a real silence ≥ 200ms means the chunker would have split
  there anyway. The seam becomes a "free" chunk boundary.
- The 200ms detection threshold is well below the chunker's 600ms — we
  pick the longest silence in a ±60s window around the target time.

**Fallback**: if no silence is found in the search window (rare; would
mean someone is talking continuously for 18 min), fall back to a
time-based cut. Mark `audio_chunks.cut_on_silence = false` for observability.

**Overlap window** (Stage 2; required for cross-chunk diarization
alignment per the algorithm above):

- For chunk_i > 0, ffmpeg cuts the chunk to start at
  `chunk_{i-1}.seam_offset_ms - overlap_ms` instead of at
  `chunk_{i-1}.seam_offset_ms`.
- Default `overlap_ms` value is `alignOverlapMinMS` (10s). ingestion-svc
  extends it up to `alignOverlapCapMS` (45s) if the prior chunk's tail
  has fewer than `alignTargetMatchedPairs` spoken-word minutes-equivalent
  (heuristic: ≥ N words in the prior chunk's trailing N seconds before
  the seam). This keeps the overlap word-density-aware without paying
  for unused audio.
- The actual overlap_ms used for a given chunk is persisted in
  `audio_chunks.overlap_ms` so the merger can reconstruct exactly which
  region of the prior chunk to consult for alignment, even if the
  algorithm constants have changed since.
- Chunks at the language-agnostic level: time anchors don't care about
  word counts, so this heuristic is a "best-effort" extension — even at
  the 10s minimum, time-anchored matching still works as long as some
  speech is present.

**Cost.** Re-billing the overlap region: each chunk's first
`overlap_ms` is the same audio as the prior chunk's last `overlap_ms`,
so Chirp transcribes it twice. At default 10s and 4 chunks per
60-min session, that's 30s of duplicate Chirp time × $0.024/min ≈
$0.012 per session. Negligible.

### Data model

New migration `migrations/000022_audio_chunks.up.sql`:

```sql
CREATE TABLE audio_chunks (
    -- One row per server-side-produced FLAC chunk. Empty for
    -- uploads ≤ 19 min (single-chunk legacy path uses the
    -- audio_uploads row directly).
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audio_upload_id UUID NOT NULL REFERENCES audio_uploads(id) ON DELETE CASCADE,
    chunk_index     INT  NOT NULL,
    -- GCS object path of THIS chunk's FLAC.
    bucket_name     TEXT NOT NULL,
    object_path     TEXT NOT NULL,
    -- Offset in the ORIGINAL upload's timeline. Used by
    -- stt-finalize to re-relativize Chirp word offsets and stitch seams.
    --   start_offset_ms ≤ seam_offset_ms ≤ end_offset_ms
    -- chunk i's overlap with chunk i-1 is the region
    --   [chunk_i.start_offset_ms, chunk_{i-1}.seam_offset_ms]
    -- which equals overlap_ms (mirrored here for query convenience
    -- without joining to chunk_{i-1}).
    start_offset_ms BIGINT NOT NULL, -- Physical start in milliseconds
    seam_offset_ms  BIGINT NOT NULL, -- Logical cut/stitch point in milliseconds
    end_offset_ms   BIGINT NOT NULL, -- Physical end in milliseconds
    -- Width of the overlap with the prior chunk. 0 for chunk_index = 0.
    -- Stored per-row so the alignment algorithm can be replayed offline
    -- with the exact overlap that produced any given session — even if
    -- the constants in the algorithm have moved since.
    overlap_ms      INT NOT NULL DEFAULT 0,
    -- Did ffmpeg find a real silence at this cut point, or did
    -- we fall back to a hard time-based cut? Pure observability.
    cut_on_silence  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (audio_upload_id, chunk_index)
);

CREATE INDEX idx_audio_chunks_upload ON audio_chunks(audio_upload_id);
```

### stt-submit `loadChunkPlan` logic

```go
func loadChunkPlan(ctx context.Context, audioUploadID uuid.UUID) ([]ChunkPlan, error) {
    rows, err := dbPool.Query(ctx, `
        SELECT chunk_index, bucket_name, object_path,
               start_offset_ms, seam_offset_ms, end_offset_ms, overlap_ms
        FROM audio_chunks
        WHERE audio_upload_id = $1
        ORDER BY chunk_index`, audioUploadID)
    if err != nil {
        return nil, err
    }
    var chunks []ChunkPlan
    for rows.Next() { /* … */ }

    if len(chunks) == 0 {
        // Stage 1 / short audio path: synthesize a single virtual
        // chunk covering the whole audio_upload. No overlap (no
        // prior chunk to align against); seam == end (no logical
        // cut). The merge loop's i==0 branch handles this without
        // running the alignment code.
        upload, err := getAudioUpload(ctx, audioUploadID)
        if err != nil {
            return nil, err
        }
        chunks = []ChunkPlan{{
            ChunkIndex:    0,
            GCSUri:        fmt.Sprintf("gs://%s/%s", upload.BucketName, upload.ObjectPath),
            StartOffsetMS: 0,
            SeamOffsetMS:  0,
            EndOffsetMS:   0,
            OverlapMS:     0,
        }}
    }
    return chunks, nil
}
```

### Idempotency on the split

Two failure modes to design out:

- **Crash mid-split.** ingestion-svc downloads + ffmpeg-splits + uploads
  chunks. If it crashes after uploading 2 of 3 chunks but before
  writing audio_chunks rows or before publishing audio.uploaded, the
  client will retry. Retry needs to (a) detect existing chunks in GCS and
  (b) not pay ffmpeg again. **Implementation**: SELECT existing
  audio_chunks rows first; if `COUNT = expected_count` and all GCS objects
  exist, skip. Else delete partial state and redo.

- **Concurrent splits.** Two clients call ConvertAudio with the same
  audio_upload_id (e.g., post-network-retry). Both run ffmpeg. **Implementation**:
  acquire `pg_advisory_xact_lock(hashtext(audio_upload_id::text))` at the
  start of ConvertAudio. Second call waits, then re-checks state, sees
  the chunks landed, and short-circuits.

---

## Failure modes summary

| Failure | Stage 1 behavior | Stage 2 behavior |
|---|---|---|
| stt-submit crashes after BatchRecognize submit but before DB insert | Pub/Sub retries; second submit hits same upload, creates a second op_id, races on `(session_id, chunk_index)` UNIQUE → InsertSTTOperation fails → ack via the race branch. **Net:** one stale op_id in Chirp (no GCS output ever lands because we don't poll), watchdog eventually marks abandoned. | Same per chunk. Watchdog has more pending rows to walk; same handling. |
| Chirp 5xx on submit | `handleSTTError` (existing) returns err → Pub/Sub retries up to topic policy. | Same. Each chunk's submit is independent — partial-success acceptable: chunks that submitted are tracked; retry only re-submits the failing ones. |
| Chirp file-level error (`"is too long"`, codec rejected) | Lands in GCS as error response. stt-finalize parses, sees Error, marks session FAILED, acks. **No retry storm** — same as today's classifier. | Stage 2's 19-min limit means "is too long" shouldn't happen on a chunk. If it does, that's a chunk-size bug; same handling. |
| Chirp succeeds but GCS write fails (rare) | Chirp's Operation completes with output URI but no object lands. stt-finalize never fires. Watchdog detects after 30 min, polls Operations API, sees DONE+blob_url, reads it, drives finalize manually. | Same per chunk. |
| Eventarc drops OBJECT_FINALIZE | Same as above — watchdog rescues. | Same. |
| Two OBJECT_FINALIZE events for the same chunk (Pub/Sub at-least-once) | First UPDATE flips finalized_at, second UPDATE's `RowsAffected = 0` → no-op return. | Same. |
| All chunks finalize simultaneously | Each invocation queries pending count; one or more see "0 pending"; `SELECT FOR UPDATE` on sessions row serializes the merge attempt. Only one wins the status flip from `TRANSCRIBING → MERGING`. | Same. |
| Merge fails partway (DB write or KMS encrypt) | Deferred handler in `mergeAndPersist` reverts `sessions.status` to TRANSCRIBING for transient errors, FAILED for terminal (via `isTerminalSTTError`). Pub/Sub retries the finalize event; the idempotent `finalized_at IS NULL` guard means we won't double-process individual chunks; we WILL re-run the merge end-to-end. The new UNIQUE constraint on `transcripts(session_id)` (migration 000021) catches the case where the prior attempt committed transcripts but crashed before publishing — finalize fetches the existing row and proceeds to publish. | Same. |
| Concurrent stt-submit invocations (Pub/Sub at-least-once during true concurrency) | Pre-flight SELECT on `stt_operations` lets the second invocation skip already-submitted chunks. Tight race window remains where both pass SELECT before either INSERTs; the UNIQUE catch is the second line of defense. Loser's orphan Chirp operation eventually writes to the same GCS prefix under a different filename; stt-finalize's idempotent UPDATE returns 0 rows on the duplicate event, leaving an unread file that OLM 7d cleans up. Cost: one extra Chirp call per concurrent-retry race. | Same per chunk. |
| Some chunks finalize, then session deleted | `ON DELETE CASCADE` on stt_operations cleans up. GCS objects survive until OLM 7d. | Same — plus audio_chunks rows cascade too. |

---

## Migration plan

### Pre-deployment

1. Migration `000021_stt_operations.up.sql` lands in main. Doesn't affect
   any running code. Migrator runs on next deploy.
2. New bucket `<project>-transcripts-raw` provisioned via terragrunt apply
   on `module.storage`. IAM grants in place (stt-worker SA can write).

### Stage 1 deploy (in this order)

1. Deploy `stt-finalize` Cloud Function with Eventarc trigger on the new
   bucket. Initially no traffic — the bucket is empty.
2. Smoke-test with a hand-uploaded fixture JSON file at the right path. Verify
   `ProcessTranscriptObject` runs, parses, persists a transcript, publishes
   `transcript.completed`. Use a test session_id; clean up after.
3. Deploy refactored `stt-worker` (`stt-submit`). At this point, every new
   `audio.uploaded` event uses the GCS callback path.
4. Smoke: e2e test with a 40s FLAC. Confirm session reaches COMPLETED.
5. Revert `infra/modules/cloud-functions/main.tf` timeout `1800 → 120` for
   stt-worker.
6. Deploy `stt-watchdog` + Cloud Scheduler entry.

**Rollback path**: revert the stt-worker source to pre-Stage-1 (inline
output). The `stt_operations` table stays empty for new sessions; existing
rows finalize on their own. Bucket stays in place (cheap).

### Stage 2 deploy

**Pre-conditions (Stage 2a code complete, Stage 2b eval harness green):**

1. `cmd/stt-align-eval/` is green for `en-US` against ≥10 captured EN
   fixtures (`translation_accuracy ≥ 0.95`, `fallback_rate ≤ 0.10`).
   If not green, hold and tune the constants in
   `internal/sttgcs/alignment.go`; only ship once green.
2. Code review on `internal/sttgcs/alignment.go` — this is the most
   algorithmically dense surface; deserves a second pair of eyes.

**Rollout steps:**

1. Migration `000022_audio_chunks.up.sql`.
2. Deploy ingestion-svc with extended `ConvertAudio` (chunking enabled).
3. Deploy refactored stt-submit + stt-finalize with the new alignment
   merger active. (Stage 1's stt-submit/stt-finalize binary is updated
   in place — same Cloud Function, new code.)
4. Update `CompleteAudioUpload` to call the split when
   `actual_duration_seconds > 1140` (= 19 minutes). This REPLACES the
   Stage 0 band-aid.
5. Remove `CreateAudioUpload`'s `estimated_duration_seconds > 1140`
   reject — the system now handles long files.
6. Watch the `stt_cross_chunk_alignment_fallback_count` metric for the
   first 72h. Alert fires if 24h rolling rate > 5%.

**Rollback path**: revert ingestion-svc to skip the split. stt-submit's
`loadChunkPlan` will still synthesize a single virtual chunk for any
audio_upload without audio_chunks rows. The alignment code path is
guarded by `chunk_count > 1` AND `used_native_diarization = TRUE`, so a
rolled-back ingestion-svc means single-chunk sessions resume — no
alignment runs. Existing long sessions in flight (rare; ≤ 24h of GCS
OLM window) might be in a half-split state — handle by manually
pruning `audio_chunks` rows + reuploading.

**Per-language extension** (post-Stage-2): to enable cross-chunk
diarization for a new language (e.g., flip `es-ES` to `true` in
`Chirp3DiarizationLanguages`):
1. Capture 3-5 chunked staging fixtures in `es-ES`.
2. Hand-label ground truth.
3. Run `cmd/stt-align-eval/` against the fixtures with
   `Chirp3DiarizationLanguages["es-ES"] = true` (locally).
4. Require ≥ 0.95 translation accuracy.
5. PR flipping the map entry; deploy.

### Stage 3 (cleanup)

1. Remove the `CreateAudioUpload` / `CompleteAudioUpload` duration
   band-aid added in Stage 0.
2. Update Flutter UI copy: drop the "max 60 min" hint, since chunking
   now handles arbitrary lengths (still bounded by GCS 5 GB and Chirp's
   8 GB per request — neither is reachable for clinical audio).
3. Update `docs/agents/04_ingestion-svc.md` and `docs/agents/05_ai-pipeline-svc.md`
   to reflect new flow.

---

## Tests

### Unit

- `internal/sttgcs/parse_test.go` — `ParseOutputObjectPath` cases:
  valid, missing session_id, non-numeric chunk_index, wrong suffix.
- `internal/sttgcs/merge_test.go` — `MergeChirpResults` with 1/2/3 chunks,
  word offset re-relativization, speaker label aggregation, confidence
  averaging, language code propagation, empty chunk handling.
- `cmd/stt-finalize/main_test.go` — `finalizeIfReady` idempotency
  (simulate two concurrent finalize events for the last chunk), merge
  lock acquisition under race.
- `cmd/stt-submit/main_test.go` — `loadChunkPlan` virtual-chunk fallback,
  audio_chunks ordering, unique-violation race handling on InsertSTTOperation.
- `services/ingestion-svc/.../converter_test.go` — extend with
  `TestChunkAudio_FindsSilenceBoundaries`, `TestChunkAudio_FallsBackOnNoSilence`.

### Integration (Docker-required)

- ffmpeg chunking against a real ≥40-min FLAC fixture: assert N=3 chunks,
  each ≤19 min, each starts on detected silence ±2s.

### E2E (staging)

- New test `tests/e2e/long_session_test.go`:
  - Upload a 25-min FLAC (synthesize via `ffmpeg -i sample.flac -filter_complex 'aloop=...'`).
  - Walk through CompleteAudioUpload → stt-submit splits → 2 chunks land
    in transcripts-raw → stt-finalize merges → llm-worker runs → report.
  - Assert chunk_count = 2, single transcripts row, single therapist_reports row.
- Extend `TestFullSession_HappyPath` to assert `stt_operations` row count = 1
  for the 40s fixture (regression guard against accidental Stage 2 path).
- New negative test: upload a deliberately corrupt FLAC, confirm Chirp's
  file-level error lands in GCS, stt-finalize marks session FAILED,
  no retry storm.

### Watchdog

- Unit test for the polling logic against a mock Operations API: PENDING
  / DONE / ERROR paths.
- Cloud Scheduler integration test: trigger via gcloud, observe nothing
  happens on a healthy DB; insert a stuck row, observe recovery.

### Offline eval harness (`cmd/stt-align-eval/`)

Required gate for Stage 2 ship + every future language flip to
`Chirp3DiarizationLanguages[lang] = true`. Mirrors `cmd/llm-eval/`
shape: CLI tool, no infra dependencies, fixture-driven.

**Inputs** (committed under `services/ai-pipeline-svc/cmd/stt-align-eval/testdata/{lang}/`):
- N raw Chirp output JSON files per language (one per chunk, captured
  from real chunked sessions in staging).
- A `ground_truth.json` per session: hand-labeled mapping of
  `(chunk_index, raw_speaker_label) → canonical_speaker_label`.

**Outputs** (per language, per session, plus aggregate):
- `translation_accuracy` — fraction of words where the algorithm's
  mapped label matches the canonical label.
- `fallback_rate` — fraction of seams that fell back to label-by-
  ordinal offset.
- `ambiguous_label_rate` — fraction of current-chunk labels that hit
  the `alignMajorityFraction` ambiguity branch.
- `unmapped_label_rate` — fraction of current-chunk words whose label
  wasn't in the translation map (new speakers entering after the seam).

**Pass criteria** for shipping a language: aggregate
`translation_accuracy ≥ 0.95` AND `fallback_rate ≤ 0.10` over ≥ 5
fixtures (10 for EN at Stage 2 launch, 3-5 for subsequent languages).

**Re-runnability.** Constants in `internal/sttgcs/alignment.go` can be
tweaked and re-evaluated without touching production. The harness
prints a diff vs. the prior run so tuning iterations are visible.

---

## Cost analysis

Per session (60-min average):

| Component | Stage 0 (today) | Stage 1+2 target |
|---|---|---|
| Cloud Function compute (stt-worker) | 30 min × 1 vCPU × 1 Gi = ~5¢ per session in degenerate cases | ~5s submit + ~30s finalize ≈ <0.5¢ |
| Chirp BatchRecognize | $0.024/min × 60 = $1.44 | Same ($1.44) — Chirp runtime is unchanged |
| ingestion-svc compute (split work) | 0 | ~30s × 2 vCPU × 2 GiB ≈ 0.2¢ per long session |
| GCS storage (transcripts-raw, 7d) | 0 | ~500 KB × 4 chunks × 7d ≈ negligible |
| GCS storage (audio_chunks, 48h) | 0 | ~80 MB × 4 chunks × 48h ≈ ~0.5¢ |
| Eventarc events | 1 (audio.uploaded) | 1 + 4 (chunk finalizes) + 1 (transcript.completed) = 6. Free tier covers 200k/month — irrelevant. |

**Net**: ~+0.7¢ per long session in exchange for solving the failure mode.
Stuck-call cost (which we paid in the multi-hour Chirp outage on 2026-05-22)
goes from $5+ per session × retries down to ~0.5¢ × retries. The big win
is reliability, not cost.

---

## Open questions

1. **Recognizer reuse.** Today we use `recognizers/_` (default). With
   GcsOutputConfig, we do **not** need a named Recognizer. The default recognizer `_`
   works perfectly because permission to write to the destination bucket is managed
   at the GCS bucket level. We simply grant `roles/storage.objectAdmin` or
   `roles/storage.objectCreator` directly to the global **Speech-to-Text Service Agent**
   (`service-{project-number}@gcp-sa-v2-speech.iam.gserviceaccount.com`) on our
   `<project>-transcripts-raw` bucket.

2. **Speaker_label continuity across chunks.** Resolved via **Overlapping
   chunks with time-anchored label alignment** (Option B). Native
   diarization stays on for every language flagged `true` in
   `Chirp3DiarizationLanguages` — EN today; ES/FR/DE/etc. as they pass
   the per-language probe.

   - In Stage 2, ingestion-svc splits the audio with an adaptive overlap
     (default 10s, extends up to 45s when word density is low). The exact
     overlap is recorded in `audio_chunks.overlap_ms` per chunk.
   - During merge, `stt-finalize` aligns words across the overlap window
     using **time anchors as the primary signal** (Chirp timestamps are
     stable across calls to within ~100–200ms), with **text edit distance
     as a tie-breaker** when multiple candidates fall in the same time
     window. This makes the algorithm **language-agnostic** (script-
     independent): works for Latin/Cyrillic scripts AND for CJK where
     word-only edit distance would break.
   - From the matched word pairs we build a co-occurrence matrix of
     speaker labels, derive a translation map for the current chunk,
     apply it to **all** of the current chunk's labels, then discard the
     duplicate words in the overlap zone.
   - Degenerate cases (silence-heavy overlaps, ambiguous co-occurrence,
     new speaker enters mid-overlap, etc.) fall back to **label-by-
     ordinal offset** (Chunk_i's "1" → `prevMaxLabel + 1`) which
     preserves intra-chunk speaker fidelity at the cost of cross-chunk
     continuity for that seam only. Fallback is observable via a
     custom Cloud Monitoring metric (`stt_cross_chunk_alignment_
     fallback_count`) with an alert when 24h rolling rate > 5%.
   - Decision table for every degenerate case is in `mergeAndPersist`
     step 2 ("Cross-chunk diarization alignment"). Constants live in
     `services/ai-pipeline-svc/internal/sttgcs/alignment.go`.

   **Eval gating.** A new offline tool `cmd/stt-align-eval/` (~200 LOC,
   mirroring `cmd/llm-eval/`) takes captured Chirp output + ground-
   truth labels and reports translation accuracy + fallback rate per
   session. Stage 2 ships only after the eval matrix shows ≥95%
   translation accuracy on 5-10 EN fixtures. Each subsequent language
   flip to `Chirp3DiarizationLanguages[lang] = true` requires the same
   eval pass for that language (3-5 fixtures, same ≥95% bar).

3. **`transcripts` table UNIQUE constraint.** **Resolved 2026-05-22**:
   - **Option (a) selected.** We add a UNIQUE constraint to `transcripts(session_id)` in
     migration `000021` (renumbered from `000019` because migrations 000019/000020 were
     already taken by recent modality work).
   - `stt-finalize` is updated to catch the unique violation error (`23505`). If it hits,
     it fetches the existing transcript ID and skips the insert, continuing to publish the
     `transcript.completed` event. This enables robust crash recovery during retries.

4. **Cloud Functions Gen2 packaging for stt-finalize.** Resolved.
   - We will utilize the **shared-zip pattern**.
   - Since both `stt-worker` and `stt-finalize` share dependencies and are in the same
     repository, we compile and package them in a single deployment ZIP.
   - We deploy two Cloud Functions Gen2 resources pointing to the same ZIP artifact, but configure
     different entry points (`ProcessAudio` vs `ProcessTranscriptObject`) using the
     `FUNCTION_TARGET` environment variable. This dramatically simplifies CI/CD.

5. **Native diarization on a chunked session.** Resolved — single-flag
   gate via `Chirp3DiarizationLanguages`.
   - The existing per-language allow-list governs **both** Chirp's
     native diarization request AND cross-chunk alignment. They are
     coupled by design: if native diarization is enabled for a language,
     alignment MUST also run on chunked sessions in that language —
     otherwise > 20-min sessions would have broken cross-chunk
     diarization. No separate flag.
   - The alignment algorithm itself is language-agnostic (time-anchored,
     not text-anchored — see Q2), so no per-language tuning of the
     algorithm is required. The eval harness gate is per-language only
     to validate that Chirp's native diarization quality in that
     language meets the bar.
   - Update to `docs/agents/05_ai-pipeline-svc.md` "Constraints on
     iteration": *"Promotion of a language to `Chirp3DiarizationLanguages[lang]
     = true` now requires probe evidence for both (a) Chirp's native
     diarization tag quality on intra-chunk audio AND (b) cross-chunk
     alignment accuracy on chunked fixtures via `cmd/stt-align-eval/`."*

6. **GCS output filename pattern.** Chirp writes
   `{prefix}/transcript_{operation_id_hash}.json` — the filename is not
   predictable from the operation_id directly. Our Eventarc trigger fires
   on any OBJECT_FINALIZE in the bucket. The filter logic must reliably
   identify "this is THE transcript output for chunk_index N of session
   session_id S". Our prefix-based scheme (`gs://bucket/{sid}/chunk_{i}/`)
   handles this — only one transcript file lands in each leaf prefix —
   but a future Chirp change that writes multiple files would need
   handling. Test: capture the exact filename pattern Chirp produces and
   doc it in `internal/sttgcs/parse.go` comments.

---

## Out of scope (deferred)

- **Streaming recognize as the primary path.** `StreamingRecognize` has no
  20-min limit but requires the audio to be streamed in real time —
  incompatible with the upload-and-process flow.
- **LongRunningRecognize (V1).** Chirp 3 lives in V2 only. Switching to a
  V1 model loses Chirp 3 accuracy gains (ADR-IMPL-001).
- **Removing word-level timestamps to get the 1-hour BatchRecognize
  limit.** Would simplify a lot but requires re-engineering the chunker
  to operate on segment-level (not word-level) offsets. Larger blast
  radius (touches diarization quality on every language).
- **Per-language tuning of the alignment algorithm.** The constants in
  `internal/sttgcs/alignment.go` are global today. If empirical evidence
  shows a specific language needs different thresholds (e.g., CJK
  scripts benefit from a tighter `alignTimeMatchToleranceMS`),
  parameterize per-language at that point — not preemptively.
- **Compaction of `stt_operations` table.** Each completed session leaves
  N rows behind. At 1000 sessions/day × 4 chunks avg = 4000 rows/day =
  ~1.5M rows/year. Acceptable for now; eventually add a compaction job
  that DELETEs rows older than 90 days (sessions are canonical; the op
  trail is for ops debugging).
- **stt-finalize's own DLQ.** Today's stt-worker has a DLQ on
  `audio.uploaded.dlq`. The new GCS-triggered finalize doesn't have a
  Pub/Sub topology — its dead-letter equivalent is the watchdog. If we
  decide to surface DLQ-style metrics, we'd add a Cloud Logging sink
  filter or a Pub/Sub republish on terminal failure.

---

## Effort estimate

| Stage | LOC | Days |
|---|---|---|
| Stage 1 (GCS callback, single-chunk) | ~600 (worker refactor ~250, finalize ~200, watchdog ~100, terraform ~50) | 5–7 |
| Stage 2a (server-side chunking + alignment) | ~900 (ingestion-svc extension ~200, stt-submit chunk loop ~50, migrations ~50, `internal/sttgcs/alignment.go` ~300, merge integration ~100, unit/fixture tests ~200) | 10–13 |
| Stage 2b (eval harness + EN validation) | ~300 (`cmd/stt-align-eval/` ~200, fixture capture + ground-truth labeling ~50, doc updates ~50) | 3–5 |
| Stage 3 (cleanup) | ~50 net delete | <1 |
| **Total** | ~1850 | **18–25 days** |

Single branch: `feat/stt-gcs-callback`. Two PRs (Stage 1 + Stage 2).
Stage 3 is a follow-up commit on main once Stage 2 is stable for a week
in production.

---

## Cross-references

### ADRs this touches
- **ADR-IMPL-001** (Chirp 3 — STT) — preserved; we're not changing the
  model, just the result-delivery channel.
- **ADR-IMPL-004** (Cloud Functions Gen2 as workers) — preserved; both
  stt-submit and stt-finalize are Gen2.
- **ADR-IMPL-006** (`transcripts.transcript_ciphertext` is canonical) —
  preserved; persistTranscript still produces the same blob, just from a
  merged word stream.
- **ADR-IMPL-007** (LLM-inferred diarization for pl-PL, chunker by
  pauses) — preserved AND extended. The chunker runs after the cross-
  chunk merge with the same input/output contract. Per-language gate
  via `Chirp3DiarizationLanguages` now controls BOTH Chirp native
  diarization AND cross-chunk alignment (coupled). Promotion of a
  language to `true` requires probe evidence for both behaviors via the
  `cmd/stt-align-eval/` harness.
- **ADR-IMPL-007a** (sparse-label recovery for native diarization) —
  preserved; `stt-worker.fillSpeakerLabels` and `llm-worker`'s orphan
  reattach run unchanged. The cross-chunk alignment composes cleanly
  with these (fill happens per-chunk before merge; orphan reattach runs
  on the merged stream after).
- **P1** (Zero Data Loss) — strengthened by the watchdog + idempotent
  finalize.
- **P3** (EU residency) — preserved; new bucket in europe-central2, same
  Speech endpoint `eu-speech.googleapis.com`.
- **ADR-DM-002** (Envelope encryption) — extended to the new bucket
  (CMEK on `transcripts-raw`).

### Files
- Pipeline flow doc: `docs/agents/05_ai-pipeline-svc.md` (lines 64–157).
- Existing stt-worker: `services/ai-pipeline-svc/cmd/stt-worker/main.go`.
- Chunker: `pkg/transcription/chunker/chunker.go`.
- Existing ingestion-svc converter (ffmpeg lives here):
  `services/ingestion-svc/internal/adapters/storage/converter.go`.
- 1800s timeout patch + deferred-fix marker:
  `infra/modules/cloud-functions/main.tf:163-187`.
- Cloud Functions packaging: `infra/modules/cloud-functions/package.sh`.
- Migrations: `migrations/000021_*`, `migrations/000022_*` (new).
- Original duration band-aid + classifier work:
  commit `a5e8f4c` (`feat(audio): iPhone M4A → FLAC conversion + codec
  defense-in-depth`).

### Related design docs
- `docs/11_IPHONE_AUDIO_CONVERSION.md` — established the ffmpeg-in-
  ingestion-svc pattern that Stage 2 reuses.
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §8 — Pipeline AI (read for context
  before editing this surface).
