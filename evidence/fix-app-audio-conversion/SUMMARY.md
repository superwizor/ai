# fix/app-audio-conversion — verification evidence

Bug: file-upload → "Konwertuję" → back navigation lost the whole session,
because conversion ran inline on NewSessionScreen BEFORE any durable
PendingUpload existed.

Fix: conversion is now a durable queue phase (UploadPhase.converting).
The row is persisted to Hive the instant the file is staged; the worker
runs UploadIo.convertSource and the pending-uploads pill tracks it even
if the user leaves the screen / kills the app.

## Results (2026-06-04)

- flutter analyze (touched files): 0 new issues. 1 pre-existing info
  (upload_queue_provider.dart:277 unintended_html_in_doc_comment) — not
  touched by this work. See analyze-touched.log.
- upload_worker_test.dart: +25 ALL PASS, incl. 4 NEW converting tests:
  - converting → pending repoints source at transcoded file
  - converting → pending keeps original + server fallback on decode failure
  - converting walks all the way to completed in successive runOnes
  - transient convert error keeps the row in converting and retries
  See worker-tests.log.
- upload_queue_test.dart: +10 all pass.
- pending_upload_test.dart: +7 all pass.

## Pre-existing failures (NOT caused by this change — verified via git stash)

- upload_state_transitions_test.dart: +2 -13 (identical on clean baseline)
- upload_queue_runner_test.dart: +3 -7 (identical on clean baseline)
  These are flaky real-timer/real-Hive runner-lifecycle tests
  (retryFailed/dismiss/connectivity). Out of scope for this fix.

## Manual device test (pending — to run on Marcin's iPhone build)

- Pick a Voice Memo .m4a → on the "Konwertuję plik audio..." status screen
  tap back → session stays in kartoteka as "W trakcie analizy", pill shows
  conversion→upload, session completes with a real transcript.
