# 11 — iPhone audio conversion: M4A → FLAC pipeline

**Status:** implemented (2026-05-20) on `feat/iphone-audio-upload`.
Pending: manual iOS-device smoke test + staging deploy + E2E run.

**Verified locally:**
- `go test ./services/ingestion-svc/...` ✓ (5 tests including FLAC magic check)
- `golangci-lint run ./...` ✓ (0 issues)
- `flutter analyze` ✓ (0 issues on touched files)
- `flutter test test/audio_converter_service_test.dart` ✓ (2 tests)
- `go build -tags=e2e ./tests/e2e/...` ✓ (new convert_audio_test.go compiles)

**File census:**
- 6 NEW files: AudioConverter.swift, converter.go, converter_test.go,
  audio_converter_service_test.dart, convert_audio_test.go, sample.m4a.
- 9 modified files: ingestion.proto + generated Go/Dart stubs,
  Dockerfile, audio_uploads.sql (+ generated), grpc/server.go,
  cmd/server/main.go, AppDelegate.swift, project.pbxproj,
  audio_converter_service.dart, new_session_screen.dart,
  docs/agents/04_ingestion-svc.md, docs/agents/06_flutter-therapist-app.md.

**Problem:** Chirp 3 (Cloud Speech v2 `europe-central2`) rejects AAC-in-MP4
containers (`.m4a`, `.aac`, `.mp4`) with `INTERNAL`/`INVALID_ARGUMENT`. Those
formats are the iPhone Voice Memos default, the WhatsApp voice-note default,
and a common iOS share-sheet export. Today we accept them through the file-
upload path, the upload completes, then the worker fails — session lands in
`FAILED` with no recovery for the therapist. Live recording is fine (Flutter
`record` package emits FLAC directly on iOS); the gap is the file-upload
path.

**Reference incident:** `d752639 fix: block m4a uploads due to Chirp 3
europe-central2 limitations` — the current workaround is to **reject** M4A
at the client. Product regression: blocks the dominant consumer audio
format on the dominant device.

---

## Decision: Option D revised — A1 (iOS native) + new ingestion-svc.ConvertAudio RPC

Two-layer fix, both shipped in the same branch:

```
   iPhone file upload
        │
        ↓
   ┌──────────────────────────────────────────────────────┐
   │ A1: iOS-native conversion (client-side)              │
   │ AudioConverterService.convertM4aToFlac()             │
   │ MethodChannel → Swift: AVAudioFile + AVAudioConverter│
   │ hardware AAC decode → 16 kHz mono → FLAC writer      │
   │ (all OS APIs, no third-party deps)                   │
   └──────────────────────────────────────────────────────┘
        │
        ├─── success → upload FLAC → existing pipeline
        │
        └─── failure (decode error, OS pre-iOS-15, future Android)
                │
                ↓
   ┌──────────────────────────────────────────────────────┐
   │ Fallback: client uploads original M4A, then calls    │
   │ ingestion.ConvertAudio(audio_upload_id) — synchronous│
   │ gRPC. ingestion-svc ships with ffmpeg in its         │
   │ Docker image; transcodes in-process, updates         │
   │ audio_uploads row, returns.                          │
   │                                                       │
   │ Client then calls CompleteAudioUpload as normal.      │
   └──────────────────────────────────────────────────────┘
        │
        ↓
   audio.uploaded Pub/Sub → stt-worker (unchanged)
```

**Why this shape instead of the alternatives:**

| Variant | Why rejected for now |
|---|---|
| A (ffmpeg_kit_flutter) | +30–50 MB binary, 30–60s mobile transcode, battery cost. |
| B (ffmpeg in stt-worker) | ADR-IMPL-004 says workers are Cloud Functions Gen2 Go binaries — no native ffmpeg buildpack. Adding ffmpeg requires Cloud Run migration. Plus: pay compute for every session. |
| C (new `transcode-svc` Cloud Run) | New SA + IAM + terraform module + Pub/Sub topology + ops page. Too heavy for "iPhone produces M4A." |
| E (reject in UI) | Current workaround. Blocks Voice Memos + WhatsApp notes. Product regression. |

**Why A1 + new RPC (not A1 + B):** ingestion-svc is already a Cloud Run
service (Docker image), so adding ffmpeg to its image is a single
Dockerfile line + a new gRPC method. No new Pub/Sub topic, no new
service, no new SA. The fallback path covers Android (pre-platform-
channel-impl), exotic codecs, and the future web/API client without
demanding a separate transcoder.

---

## A1 feasibility — verified

Original analysis claimed iOS would need a "+5 MB FLAC framework
bundle." That's wrong — `kAudioFormatFLAC` + `kAudioFileFLACType` have
been part of `AudioToolbox.framework` since **iOS 11 (2017)**. Our
Podfile's `platform :ios, '15.0'` is well above the requirement. The
`record_ios` pod already links `AudioToolbox.framework` (uses it for
the live FLAC recording path). **Binary cost for A1 is ~0 MB.**

Verified APIs (all OS-built-in, no third-party deps):

```swift
// Decode side — AAC inside MP4 container
let inputFile = try AVAudioFile(forReading: m4aURL)
// AAC decoder is part of AudioToolbox; hardware-accelerated on Apple
// Silicon. AVAudioFile transparently decodes via AudioConverter.

// Resample to 16 kHz mono
let outputFormat = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 16000,
    channels: 1,
    interleaved: true
)!
let converter = AVAudioConverter(from: inputFile.processingFormat, to: outputFormat)!

// Encode side — FLAC writer
let outFile = try AVAudioFile(
    forWriting: flacURL,
    settings: [
        AVFormatIDKey: kAudioFormatFLAC,
        AVSampleRateKey: 16000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
    ],
    commonFormat: .pcmFormatInt16,
    interleaved: true
)
```

Performance target on iPhone 15: **~5–10× realtime decode/encode** for
60-min input — converts a typical clinical session in 6–12s with
hardware acceleration. Battery cost is negligible vs the upload itself.

---

## Phase 1 — Client (Flutter + iOS native)

### Files to touch

| File | Change |
|---|---|
| `flutter-app/superwizor/ios/Runner/AudioConverter.swift` (NEW) | Swift class implementing `MethodChannel` + `EventChannel` for progress. ~150 LOC. |
| `flutter-app/superwizor/ios/Runner/AppDelegate.swift` | Register the method channel. ~5 LOC. |
| `flutter-app/superwizor/lib/services/audio_converter_service.dart` | New method `convertM4aToFlac(inputPath, {onProgress})`. ~50 LOC. |
| `flutter-app/superwizor/lib/screens/new_session_screen.dart` | Insert the M4A branch after the existing WAV branch in the upload flow. ~25 LOC. |
| `flutter-app/superwizor/lib/screens/new_session_screen.dart` | Re-enable `.m4a`, `.aac`, `.mp4` in `_kSupportedAudioTypes` (currently removed by `d752639`). |

### Method signature

```dart
// Returns the converted FLAC File. Throws on hard failure (corrupt
// file, codec unsupported by iOS). Caller treats throw as "fall
// through to server-side ConvertAudio RPC."
Future<File> convertM4aToFlac(
  String inputPath, {
  void Function(double progress01)? onProgress,
}) async {
  if (!Platform.isIOS) {
    throw UnsupportedError('M4A platform-channel converter is iOS-only today');
  }
  // ...
}
```

### Flow change in `new_session_screen.dart`

```dart
} else if (ext == '.m4a' || ext == '.mp4' || ext == '.aac') {
  try {
    final flac = await converter.convertM4aToFlac(
      file.path,
      onProgress: (p) => setState(() => _convertProgress = p),
    );
    tempFile = flac;
    fileToUpload = flac;
    contentType = 'audio/flac';
    uploadSize = await flac.length();
    // success — proceed with normal upload path
  } catch (e) {
    // Fall through to server-side ConvertAudio. Upload the original
    // M4A; backend handles conversion. Logged with breadcrumb.
    fileToUpload = file;
    contentType = 'audio/m4a';
    uploadSize = await file.length();
    _convertedServerSide = true; // gate the post-upload RPC call
  }
}
```

After upload completion (signed URL PUT succeeded, before
`CompleteAudioUpload`):

```dart
if (_convertedServerSide) {
  // Server-side fallback. Synchronous gRPC; shows a spinner in UI.
  await ingestionClient.convertAudio(ConvertAudioRequest(
    audioUploadId: uploadId,
  ));
  // ingestion-svc has rewritten object_path + content_type in DB
  // and replaced the GCS object. Now proceed.
}
await ingestionClient.completeAudioUpload(...);
```

### UX

- Progress indicator while converting (client-side): "Konwertuję plik audio…"
  with a 0–100% bar. ~5–10s for 60-min files on iPhone 15.
- If conversion exceeds 30s (slow device, very long file): show
  "Konwersja trwa dłużej niż zwykle" with a Cancel button.
- On exception (caught above): silent fall-through. UI shows generic
  "Wysyłam…" — server-side conversion adds 30–60s but doesn't expose
  the user to error noise.

---

## Phase 2 — Server (ingestion-svc.ConvertAudio RPC)

### Proto change

`proto/ingestion/v1/ingestion.proto`:

```proto
service IngestionService {
  // ... existing RPCs ...

  // ConvertAudio transcodes an uploaded audio file to FLAC 16 kHz
  // mono in-place. Used as a fallback for client-side conversion
  // failures (iOS pre-15 edge cases, Android pre-platform-channel-
  // impl, corrupt M4A that AVAudioFile can't decode). Synchronous —
  // returns when the GCS object has been replaced and the
  // audio_uploads row updated. ~30-60s for typical session length.
  //
  // No-op when audio_uploads.content_type is already FLAC/WAV/OGG-
  // OPUS or other Chirp-supported format.
  //
  // Idempotent: re-calling on an already-converted upload returns OK
  // without re-running ffmpeg.
  rpc ConvertAudio(ConvertAudioRequest) returns (ConvertAudioResponse);
}

message ConvertAudioRequest {
  string audio_upload_id = 1;
  // Optional: explicit target format. Defaults to "audio/flac" when
  // empty. Supported: "audio/flac", "audio/wav" (LINEAR16). Other
  // values return InvalidArgument.
  string target_content_type = 2;
}

message ConvertAudioResponse {
  // Final content_type after conversion. Always FLAC unless the
  // caller asked for WAV.
  string content_type = 1;
  // GCS object_path of the converted file (may equal the original
  // path if the file was already in a supported format and
  // conversion was a no-op).
  string object_path = 2;
}
```

### Service-side changes

| File | Change |
|---|---|
| `services/ingestion-svc/Dockerfile` | Add `RUN apt-get install -y ffmpeg` (alpine: `apk add ffmpeg`). +~40 MB to image. |
| `services/ingestion-svc/internal/adapters/grpc/server.go` | New `ConvertAudio` handler. |
| `services/ingestion-svc/internal/adapters/storage/converter.go` (NEW) | `Convert(ctx, srcObjectPath, srcContentType, dstFormat) (newObjectPath, error)`. Downloads from GCS, shells out to ffmpeg, uploads back. |
| `services/ingestion-svc/internal/adapters/postgres/queries/audio_uploads.sql` | New `UpdateAudioUploadAfterConversion(id, new_object_path, new_content_type)`. |

### Handler flow

```go
func (s *Server) ConvertAudio(ctx context.Context, req *ingestionv1.ConvertAudioRequest) (*ingestionv1.ConvertAudioResponse, error) {
    uploadID, err := uuid.Parse(req.AudioUploadId)
    if err != nil {
        return nil, status.Error(codes.InvalidArgument, "invalid audio_upload_id")
    }
    upload, err := s.queries.GetAudioUpload(ctx, ...)
    if err != nil {
        return nil, status.Error(codes.NotFound, "audio upload not found")
    }

    // Idempotency: already in a Chirp-supported format → no-op.
    if isChirpSupported(upload.ContentType) {
        return &ingestionv1.ConvertAudioResponse{
            ContentType: upload.ContentType,
            ObjectPath:  upload.ObjectPath,
        }, nil
    }

    target := req.TargetContentType
    if target == "" {
        target = "audio/flac"
    }
    if !isValidTargetFormat(target) {
        return nil, status.Errorf(codes.InvalidArgument, "unsupported target: %s", target)
    }

    // Transcode. ffmpeg shells out; download/upload via GCS client.
    newObjectPath, err := s.converter.Convert(
        ctx,
        upload.BucketName, upload.ObjectPath, upload.ContentType,
        target,
    )
    if err != nil {
        return nil, status.Errorf(codes.Internal, "transcode failed: %v", err)
    }

    // Atomic update: object_path + content_type. The OLD object is
    // deleted by the converter after the new one lands (object-lifecycle
    // safety: old GCS object's OLM 48h policy still ticks if cleanup
    // fails, so we never leak storage).
    if err := s.queries.UpdateAudioUploadAfterConversion(ctx, ...); err != nil {
        return nil, status.Errorf(codes.Internal, "db update: %v", err)
    }

    return &ingestionv1.ConvertAudioResponse{
        ContentType: target,
        ObjectPath:  newObjectPath,
    }, nil
}
```

### ffmpeg invocation

```go
func (c *Converter) ffmpegToFlac(ctx context.Context, inputPath string) (string, error) {
    outputPath := strings.TrimSuffix(inputPath, filepath.Ext(inputPath)) + ".flac"
    cmd := exec.CommandContext(ctx, "ffmpeg",
        "-i", inputPath,
        "-ar", "16000",            // 16 kHz sample rate
        "-ac", "1",                // mono
        "-c:a", "flac",            // FLAC encoder
        "-compression_level", "5", // default; balanced
        "-y",                      // overwrite if exists
        outputPath,
    )
    cmd.Stderr = &bytes.Buffer{}
    if err := cmd.Run(); err != nil {
        return "", fmt.Errorf("ffmpeg: %w (stderr: %s)", err, stderr.String())
    }
    return outputPath, nil
}
```

### Cloud Run resource bump

Current ingestion-svc CPU/memory is fine for signed-URL minting (lightweight).
ConvertAudio is CPU-bound for ~30-60s per call. Two options:

1. **Increase memory + CPU** on ingestion-svc: bump to 2 vCPU / 2 GiB, enable
   `--cpu-boost` so cold starts are fast. ~$0.001/conversion incremental cost.
2. **Concurrency=1** during conversion: a single 60-min m4a → flac takes
   ~30-60s of CPU. Without concurrency=1, multiple concurrent conversions
   thrash the same instance and slow everyone down. Cloud Run's
   `--concurrency=1` is fine for our load (sub-1000 sessions/day for the
   foreseeable future).

Trade-off documented; pick #1 unless we see budget concerns.

### Failure modes

| Failure | Behavior |
|---|---|
| ffmpeg not in image | `exec: "ffmpeg": executable file not found` — log + return Internal. Smoke test in CI catches this. |
| Corrupt source file | ffmpeg returns non-zero. Surface as `codes.InvalidArgument` with the stderr in the gRPC message (truncated to 1KB). |
| GCS download fails | Network error. Retry once internally; if still failing, return `codes.Unavailable`. |
| GCS upload fails | Same as download. Old object stays on GCS (OLM 48h handles cleanup). |
| DB update fails after upload | Manual cleanup needed. Log loudly + Sentry alert. |
| Timeout (Cloud Run request budget) | Default is 60s. Bump to 300s for ingestion-svc. |

---

## Phase 3 — Testing

### Unit tests

- `audio_converter_service_test.dart`: mock `MethodChannel` (Flutter test pattern), assert `convertM4aToFlac` throws on `UnsupportedError` for non-iOS platforms.
- `ingestion-svc/.../grpc/converter_test.go`: integration test against a real ffmpeg binary in CI (Docker image already has it post-Dockerfile change). Smoke test: convert a 10-second M4A → FLAC; verify FLAC output has 16 kHz mono, 16-bit PCM.

### E2E

- New `tests/e2e/full_session_test.go` variant: `TestFullSession_M4AUpload_ServerConversion` — uploads `testdata/sample.m4a` (need to add), calls `ConvertAudio` directly (skipping client-side conversion to exercise the server path), then `CompleteAudioUpload`, then asserts stt-worker successfully transcribes.
- Existing happy-path test still uses FLAC live recording — covers the A1 path implicitly once the iOS native code ships.
- iOS-device manual test: upload a Voice Memos m4a, watch the conversion progress UI, confirm the resulting session reaches `COMPLETED` with a real transcript.

### Test data

- Add `tests/e2e/testdata/sample.m4a` (≤2 MB) — 10s of synthesized speech for the M4A path. Source from existing `sample.wav` via `ffmpeg -i sample.wav -c:a aac sample.m4a` (commit the .m4a, not the script).

---

## Risk + rollback

| Risk | Mitigation |
|---|---|
| iOS native FLAC encoder rejects 16 kHz | Verified: `kAudioFormatFLAC` accepts arbitrary sample rates since iOS 11. If a future iOS revision regresses, fall through to server-side. |
| ffmpeg in ingestion-svc image inflates cold-start | +40 MB image, ~1s additional cold start. Acceptable. Mitigated by min-instances=1 if it ever matters. |
| Memory peak during 60-min M4A transcode | ffmpeg streams in/out; max RSS ~150 MB. 2 GiB cap leaves comfortable headroom. |
| Client-side conversion produces invalid FLAC | Catch the upload-reject (Chirp returns `INVALID_ARGUMENT`); fall through to server-side conversion as a self-heal. Add a metric on `client_conversion_invalid_count`. |
| User cancels mid-conversion | `MethodChannel` task cancellation propagates to `AVAudioFile` close. Partial flac file deleted on cancel. |

**Rollback story:** Phase 1 (client) is opt-in by content-type — reverting the `_kSupportedAudioTypes` change restores today's behavior (reject M4A in UI). Phase 2 (server) is additive — removing the RPC method is a one-commit revert; the Dockerfile ffmpeg line can stay (unused but cheap). No data migration.

---

## DoD criteria

- [ ] Voice Memos M4A uploaded from iPhone 15+ reaches `COMPLETED` session status with a real transcript.
- [ ] Conversion progress UI shows a meaningful 0-100% bar (not "indeterminate").
- [ ] Conversion latency p50 ≤ 10s for a 60-min file on iPhone 15.
- [ ] Server-side `ConvertAudio` RPC handles a 60-min M4A in ≤ 90s p99 on Cloud Run 2 vCPU.
- [ ] `_kSupportedAudioTypes` re-includes `.m4a`, `.aac`, `.mp4`.
- [ ] Unit test for `convertM4aToFlac` Dart-side platform-channel mock passes.
- [ ] Integration test for ffmpeg path in CI passes.
- [ ] E2E `TestFullSession_M4AUpload_ServerConversion` green on staging.
- [ ] Manual test: iPhone Voice Memos export → upload → report generated.
- [ ] `docs/agents/04_ingestion-svc.md` updated with the new ConvertAudio RPC.

---

## What's NOT in this branch (deferred)

- **Android M4A support.** Android has `MediaCodec` for AAC decode; we'd
  write a Kotlin equivalent of `AudioConverter.swift`. Same shape, +1
  week. For now, Android files fall through to server-side `ConvertAudio`.
- **Web upload support.** Web Audio API can decode AAC but FLAC encoding
  in browser is non-trivial (need `flac.wasm`). Server-side `ConvertAudio`
  covers this case.
- **Format auto-detection.** Today we trust the file extension. A
  malicious upload with `.m4a` extension containing a different codec
  would fail ffmpeg with a clear error — acceptable for the test-flight
  audience.
- **Bitrate / quality tuning.** ffmpeg defaults are fine for clinical
  speech. Revisit if Chirp transcription quality degrades.

---

## Estimated effort

| Phase | LOC | Effort |
|---|---|---|
| Phase 1 (iOS native + Flutter glue + UI) | ~250 | 2-3 days |
| Phase 2 (proto + ingestion-svc + Dockerfile + sqlc) | ~300 | 2 days |
| Phase 3 (tests + e2e + docs) | ~200 | 1 day |
| **Total** | ~750 | **~5-6 days** |

Single branch: `feat/iphone-audio-upload`. Single PR. Ships Phase 1+2+3 together.

---

## Cross-references

- `docs/06_FAZA_2_INGESTION_AI.md` — upload pipeline architecture (Pub/Sub topology).
- `docs/agents/04_ingestion-svc.md` — ingestion-svc agent doc (will gain ConvertAudio section).
- `docs/agents/05_ai-pipeline-svc.md` — stt-worker doc (unchanged by this work; called out for completeness).
- `services/ai-pipeline-svc/cmd/stt-worker/main.go:355,493-501` — current Chirp rejection site with the explicit codec list.
- `flutter-app/superwizor/lib/services/audio_converter_service.dart` — existing WAV normalization pattern to mirror.
- `lib/screens/new_session_screen.dart:47-59` — current `_kSupportedAudioTypes` (M4A currently removed; restore in this branch).
- `d752639 fix: block m4a uploads due to Chirp 3 europe-central2 limitations` — the current workaround being undone.
