---
name: secure-recording-and-uploads
description: Details the resumable audio upload worker, recording interruption resilience (phone calls), and GCS encryption recovery.
---

# Secure Recording & Uploads Skill

## 1. Recording Interruption Resilience
When an audio recording is interrupted by a phone call on iOS/Android:
* The native plugin syncs state to the Flutter app.
* A recording manifest tracks active recordings.
* Orphaned recordings from abrupt app terminations are recovered and decrypted from local storage on next app launch. Ensure tests in `lib/uploads/` pass when modifying this.

## 2. Resumable Uploads
* Instead of a single-shot PUT, use GCS Resumable Uploads for network resilience.
* The Flutter `UploadWorker` reads chunks from the encrypted local FLAC file.
* If a transfer stalls, the worker resumes from the last byte offset recorded.
* The server finalizes the upload "exactly-once" via Eventarc (`ingestion-finalize`).
