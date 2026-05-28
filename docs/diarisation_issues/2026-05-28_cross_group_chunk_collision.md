# 2026-05-28 — cross-group chunk collision in call-1 markdown

> **Status:** root cause identified, fix landed on
> `fix/diarization-cross-group-dup-tolerant` (commit `584197c`), awaiting
> production deploy + manual nudge of affected sessions.
> **Severity:** high — sessions reach "transcribed" then stick
> forever, never producing a report. User-visible as "the app
> froze after recording."
> **Affected user reported:** therapist `marcinekojurty@gmail.com`,
> session `ee888aff-0db7-4b90-a10d-b1c3df05efbf` (one confirmed in
> the last 48h trace; broader scan blocked by classifier).

## Symptom

The Flutter iPhone client records audio, the file uploads, the user
sees the "Transcribing…" step complete, and then the session
permanently sits in `GENERATING_REPORT` state. No report ever
appears. No client-visible error. Force-quitting + re-opening the
app shows the same state — Pub/Sub is still cycling on the backend
but the front-end doesn't see it.

## Pipeline trace (one session)

Session `ee888aff-0db7-4b90-a10d-b1c3df05efbf`, 2026-05-28 UTC:

| Time (UTC) | Service | Event |
|------------|---------|-------|
| 09:03:24 | ingestion-svc | `CreateAudioUpload` received |
| 09:04:32 – 09:04:41 | ingestion-svc | Upload finalized; dispatched to STT |
| 09:04:41 – 09:04:42 | stt-worker | Per-chunk transcription completed (~1s) |
| 09:06:48 – 09:08:41 | stt-finalize | Canonical KMS-encrypted blob built; envelope published to llm-worker topic |
| 09:07:09 | llm-worker | Call-1 (diarization + metadata) attempted |
| 09:09:38 | llm-worker | Vertex / Gemini response received |
| **09:09:39** | **llm-worker** | **`Function error: generate: parse markdown metadata: diarization: chunk index appears in multiple groups: chunk 369 in groups 1 and 2`** |
| 09:09:52 | llm-worker (new instance) | Pub/Sub redeliver. Same Vertex call → same kind of overlap → same parse fail. |
| 09:15:37 | llm-worker (new instance) | Another redeliver. Same fail. |
| … | | Continues until the topic's retry-budget exhausts; message lands in DLQ (no alert wired). |

## Where call-1 sits in the pipeline

```
iPhone app
   │  records + chunks audio, uploads via signed URL
   ▼
ingestion-svc                CreateAudioUpload — billing reserve + GCS signed URLs
   │
   ▼
stt-worker                   Whisper / Chirp per-chunk transcription
   │  parallel fan-out
   ▼
stt-finalize                 builds canonical transcript blob (KMS-encrypted)
   │  publishes one envelope → llm-worker call-1 topic
   ▼
llm-worker                   call-1 = diarization + metadata (markdown)   ← bug here
                             call-2 = the actual session report
   │
   ▼
clinical-svc                 persists report, fires "report_ready" notification
```

The bug lives entirely inside llm-worker's **call-1 markdown parser**.

## What call-1 actually returns

`llm-worker` asks Gemini, in one call:

1. **Diarize** — group transcript chunks by speaker.
2. **Emit metadata** — short title + summary + overall confidence.

The prompt instructs Gemini to return Markdown like:

```markdown
# Speakers

## Group 1 — therapist (confidence 0.87)
Chunks: 0, 2, 5, 8, 12, 14, 17
Evidence: "Z czym dzisiaj przychodzisz?"

## Group 2 — patient (confidence 0.92)
Chunks: 1, 3, 6, 9, 13, 15, 18, 19
Evidence: "Trochę zmęczona ostatnio."

# Metadata
Title: Pierwsza sesja - problemy ze snem
Summary: Pacjentka zgłasza objawy bezsenności od 3 tygodni.
Overall_diarization_confidence: 0.89
```

`Chunks:` is a comma-separated list of chunk indices. The implicit
contract: **every chunk in the transcript appears in exactly one
group**. That contract holds across thousands of healthy sessions.

## What Gemini actually emitted for this session

Structurally:

```markdown
# Speakers
## Group 1 — therapist (confidence 0.86)
Chunks: …, 365, 367, 369, 371, …       ← chunk 369 here

## Group 2 — patient (confidence 0.89)
Chunks: …, 368, 369, 370, …            ← chunk 369 ALSO here
```

Chunk 369 listed in **both** groups.

This is a **generation-time hallucination**, not data corruption
upstream — the transcript chunks are uniquely numbered and arrive
once each. When Gemini is uncertain about who spoke a particular
chunk (e.g. a quiet "mhm" that could come from either speaker), it
sometimes hedges by listing the chunk in both groups instead of
picking one. Same pattern shows up in other LLM-as-classifier
settings; it's a known model-quality failure mode, not a Superwizor
bug.

## What the parser was doing about it

`services/ai-pipeline-svc/internal/diarization/markdown.go`, around
line 268:

```go
for _, ci := range indices {
    if prev, dup := seenChunk[ci]; dup {
        return Result{}, fmt.Errorf("%w: chunk %d in groups %d and %d",
            ErrDuplicateChunkAssignment, ci, prev, current.Index)
    }
    seenChunk[ci] = current.Index
}
```

`seenChunk` is a `map[int]int` — `chunk_index → first_group_it_was_in`.
The first time the parser encountered the same `chunk_index` again
(i.e. listed in a later group too), it bailed with
`ErrDuplicateChunkAssignment`.

The reasoning at the time the guard was added: if the same chunk
says "the therapist said this" AND "the patient said this",
downstream code might emit the wrong role for the chunk. Reject and
force a retry.

## Why retries didn't help — the doom loop

`llm-worker` is a Cloud Function (Gen2) subscribed to a Pub/Sub
topic. A non-2xx return makes Pub/Sub redeliver the envelope after
the visibility timeout (default 600s, but redelivery happens
sooner when the function exits cleanly with an error).

The full loop for this session:

1. llm-worker pulls envelope. Calls Vertex. Returns markdown with
   chunk 369 in two groups. Parser bails. Function returns 500.
2. Pub/Sub redelivers ~13s later. Different llm-worker instance
   pulls. Same prompt, same audio, same canonical blob → same
   Gemini call.
3. Temperature is non-zero (~0.4) so the response isn't bit-
   identical. But it's *deterministic-ish*: the audio quality
   issue that made Gemini hedge on chunk 369 the first time is
   still there. Each retry produces a slightly different markdown,
   but with the same kind of overlap somewhere in the chunk range.
4. Parser bails again. 500 again. Pub/Sub redelivers again.
5. After the topic's retry budget exhausts (~7 attempts), the
   message lands in DLQ. There's no alarm on this DLQ today, so
   the session just sits there.

The session DB row stays at `state=GENERATING_REPORT` because
llm-worker never reached the "write report" step — it died at parse
time, before any DB write.

## Why the user sees "the app froze"

The Flutter app polls `clinical-svc.GetSessionDetails(session_id)`
every few seconds while a session is in flight. The state enum
moves through:

```
UPLOADING → TRANSCRIBING → GENERATING_REPORT → REPORT_READY
```

Marcin's stuck session got to `GENERATING_REPORT` and stayed there
forever, because:

- The state column is updated by clinical-svc only when llm-worker
  successfully writes a report.
- llm-worker died at parse, never wrote a report, never published
  the "report_ready" event.
- Pub/Sub retries happen behind the API — the client never sees a
  retry-in-progress signal.

To Marcin, who's not technical, this reads as "didn't proceed to
transcription" — he conflates "the whole flow" with "transcription"
because the transcription is the slowest visible step. The actual
transcription completed fine; it's report generation that's stuck.

## Fix

Branch `fix/diarization-cross-group-dup-tolerant`, commit `584197c`.

Replaced the hard error with **first-group-wins, drop-and-count**:

```go
filtered := indices[:0]
for _, ci := range indices {
    if _, dup := seenChunk[ci]; dup {
        res.DroppedDuplicates++
        continue
    }
    seenChunk[ci] = current.Index
    filtered = append(filtered, ci)
}
current.ChunkIndices = filtered
```

Plus:

- `Result.DroppedDuplicates int` — new field on the parser output
  so callers can observe and metric the case.
- `ErrDuplicateChunkAssignment` — marked deprecated, kept for
  callers that may still defensively `errors.Is` against it.
- llm-worker logs `slog.Warn("diarization parser dropped cross-group
  duplicate chunks", ...)` when `DroppedDuplicates > 0`. Healthy
  sessions log nothing; non-zero is a quality signal.

### Why first-group-wins is safe

1. **Downstream uses ChunkIndices verbatim.** `markdownResultToPayload`
   in `cmd/llm-worker/main.go` iterates each speaker's `ChunkIndices`
   and writes them into the persisted `SpeakerGroup`. A chunk dropped
   from group 2 just means group 2 has one fewer chunk attached —
   the chunk still gets attributed to group 1 (the first claim).
   **No double-attribution makes it to the database**, which was
   the original concern motivating the strict guard.

2. **Within-group duplicates still error.** `parseChunkList` rejects
   `Chunks: 0, 0, 1` with `ErrInvalidChunkList`. That's malformed
   single-line input — the LLM emitting literal nonsense — and it
   stays a hard fail. The relaxation only covers the case where
   each group's list is *self-consistent* but the lists *overlap*.

3. **Empty-group edge case is already handled.** `finalizeCurrentGroup`
   drops a speaker whose `ChunkIndices` is empty. If the LLM emitted
   `Group 2: 369` and group 1 already claimed 369, group 2 becomes
   empty and is silently elided — we ship the report as a single-
   speaker session rather than a phantom 2-speaker session with one
   empty role. Test `TestParse_AllChunksDroppedAsDuplicatesElidesGroup`
   pins that contract.

### Trade-off

Chunk 369 gets attributed to the therapist when the LLM was uncertain.
That's no worse than what the LLM would have produced if it had
picked one role — and the user gets a report instead of nothing.

If `DroppedDuplicates > 0` starts firing on >5% of sessions, the
remediation is the **prompt**, not the parser — we'd tighten the
instruction set ("each chunk MUST appear in exactly one group; if
unsure, pick the more confident speaker"). The parser stays
tolerant either way.

## Tests added

- `TestParse_DuplicateChunkAcrossGroupsDropsAndContinues` — replaces
  the old `TestParse_DuplicateChunkAcrossGroups`. Asserts that
  cross-group overlap no longer errors, `DroppedDuplicates == 1`,
  group 1 keeps `[0,2,5]`, group 2 keeps `[3,6]` (dropped the
  colliding 2).
- `TestParse_AllChunksDroppedAsDuplicatesElidesGroup` — every chunk
  in group 2 collides; `DroppedDuplicates == 3`, only one speaker
  in `Result.Speakers`, group 2 elided.

## Deploy + recovery procedure

```bash
# 1. Push the fix branch
git push -u origin fix/diarization-cross-group-dup-tolerant

# 2. Deploy llm-worker (Cloud Function Gen2). Two options:

# 2a. Via terragrunt (preferred — source-zip hash change re-deploys)
cd superwizor-backend/infra/environments/staging
terragrunt apply -target=module.cloud_functions.google_cloudfunctions2_function.llm_worker

# 2b. Via Cloud Build (if the CI route is wired)
cd /Users/dpiotrak/supervisorai_v2/ai
gh pr create --base main --head fix/diarization-cross-group-dup-tolerant
# merge → CI redeploys

# 3. Verify the new revision is serving
gcloud functions describe llm-worker --region=europe-central2 \
  --format='value(updateTime,buildConfig.runtime)' \
  --project=superwizor-ai-25ecd

# 4. Find the call-1 trigger topic
gcloud pubsub topics list --filter="name:llm-worker" \
  --format="value(name)" \
  --project=superwizor-ai-25ecd

# 5. Republish the envelope for each stuck session.
# Adjust the JSON shape to match docs/17 §5 — the field name might
# be session_id, sessionId, or wrapped under "data" base64-encoded
# depending on the topic schema. Check one healthy envelope from
# the topic's recent traffic before publishing.
gcloud pubsub topics publish \
  projects/superwizor-ai-25ecd/topics/llm-worker-trigger \
  --message='{"session_id":"ee888aff-0db7-4b90-a10d-b1c3df05efbf"}' \
  --project=superwizor-ai-25ecd

# 6. Watch the session state via clinical-svc:
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="llm-worker"
   AND textPayload:"ee888aff"
   AND timestamp>="'$(date -u -v-5M +%Y-%m-%dT%H:%M:%SZ)'"' \
  --limit=20 --project=superwizor-ai-25ecd
```

Marcin's iPhone should see the session jump from `GENERATING_REPORT`
→ `REPORT_READY` within ~30 seconds after step 5 completes
successfully on the new revision.

## Follow-ups not done in this fix

These should land as separate work:

1. **DLQ alarm on the llm-worker topic.** Today there's no
   monitoring that fires when sessions get parked. A simple
   Cloud Monitoring alert on `pubsub.googleapis.com/topic/dead_letter_message_count`
   per topic would surface stuck sessions in <5 minutes instead of
   "the user complains in Slack".

2. **Session timeout state.** clinical-svc could mark sessions
   `state=REPORT_FAILED` after N minutes in `GENERATING_REPORT`
   without a report write. The iPhone would then show "report
   generation failed — try again" instead of looking frozen. Needs
   a Cloud Scheduler tick + a sweep query.

3. **Front-end "stuck session" detection.** Client-side, if a
   session has been in `GENERATING_REPORT` for >10 min, surface a
   "we're still working on this — contact support if it stays here"
   banner. Easier UX win than waiting for the server-side timeout.

4. **Tighten the call-1 prompt.** Add an explicit "each chunk
   appears in EXACTLY ONE group" line near the output-format
   instructions. Won't eliminate the issue (LLMs ignore
   instructions sometimes) but should reduce the rate of
   `DroppedDuplicates > 0` logs.

5. **Broader scan for stuck sessions.** I only confirmed one
   affected session from 48h of logs. A query of all sessions
   currently `state=GENERATING_REPORT` AND `updated_at < now() -
   interval '1 hour'` would surface every stuck case, not just
   the ones in recent log retention.

## References

- Failing commit pinned by tests/golden file: see
  `services/ai-pipeline-svc/internal/diarization/markdown_test.go`
  before this fix.
- Pipeline architecture: `docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md`,
  `docs/15_HYBRID_EVENTARC_FINALIZATION.md`.
- Session-state contract: `docs/17_BILLING_IMPLEMENTATION_FLOW.md §5`
  (post-Phase-D rewrite — the canonical-blob description).
- Prior diarization-tolerance precedent: 2026-05-18 "Agnieszka
  incident" → relaxed the empty-`Chunks:` line. See
  `TestParse_EmptyChunksDropsGroup`. This fix is the same shape:
  parse tolerance for an LLM-quality glitch that doesn't actually
  break downstream data integrity.
