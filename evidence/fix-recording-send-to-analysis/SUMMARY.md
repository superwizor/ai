# fix/recording-send-to-analysis — verification evidence

Bug: live recording → "send to analysis" → the screen sat for a long time
behind a bare, label-less spinner with no info; user couldn't tell what was
happening or how to avoid losing the session.

Root cause (same class as fix/app-audio-conversion): RecordingScreen
._finishAndUpload ran storage.encryptRecording() inline — a multi-step
AES-GCM pass over the whole recording — BEFORE enqueuing any durable
PendingUpload, behind `if (_uploading) CircularProgressIndicator()` with no
text. Leaving the screen / app-kill / OS purge during that window lost the
session; and there was no feedback.

Fix: encryption is now a durable queue phase (UploadPhase.encrypting). On
stop, RecordingScreen enqueues a phase=encrypting row pointing at the raw
FLAC already in durable Documents storage (<docs>/sessions/<id>/raw.flac),
then navigates immediately. The worker runs UploadIo.encryptSource
(SecureAudioStorageService.encryptRecording) to produce chunk_*.enc + delete
raw, then advances to pending → created → completed. The kartoteka card +
pending-uploads pill show "W trakcie przetwarzania"; SessionStatusScreen
shows "Przetwarzanie nagrania..." plus a "Możesz bezpiecznie opuścić ten
ekran" reassurance line.

## Results (2026-06-04)

- flutter analyze (touched lib + test/uploads): 0 new issues. 1 pre-existing
  info (upload_queue_provider.dart:277) — untouched. See analyze.log.
- upload_worker_test.dart: +28 ALL PASS, incl. 3 NEW encrypting tests:
  - encrypting → pending stamps chunkCount + plaintext size
  - encrypting walks all the way to completed
  - transient encrypt error keeps the row in encrypting and retries
  See worker-tests.log.
- upload_queue_test.dart +10, pending_upload_test.dart +7 — all pass.

## Pre-existing failures (NOT caused by this change)

- upload_state_transitions_test.dart +2 -13, upload_queue_runner_test.dart
  +3 -7 — identical counts to the clean baseline (flaky real-timer/Hive
  runner-lifecycle tests). Both still compile after adding encryptSource to
  their fakes. Tracked separately.

## Manual device test (pending)

- Record a session → "Zakończenie i analiza" → confirm: immediate navigation
  to the status screen showing "Przetwarzanie nagrania...", the session
  appears in kartoteka as "W trakcie przetwarzania" with the pill tracking,
  leaving the screen does not lose it, and it completes with a transcript.
