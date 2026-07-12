---
type: System Documentation
title: "28 — Recording Interruption Resilience (phone-call loss bug)"
description: "---"
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/28_RECORDING_INTERRUPTION_RESILIENCE.md
tags: []
timestamp: 2026-06-10T09:38:07+02:00
---

# 28 — Recording Interruption Resilience (phone-call loss bug)

| | |
|---|---|
| **Status** | IMPLEMENTED (WS1–WS5) on `fix/recording-call-interruption` — on-device verification (§8.3 M1–M10) pending before merge. R1 resolved: recovered FLAC forced through server-side ffmpeg re-encode via `audio/x-flac`. |
| **Date** | 2026-06-09 |
| **Branch** | `fix/recording-call-interruption` (off `main`) |
| **Owner** | Flutter app (`flutter-app/superwizor`) + 1 small iOS native helper |
| **Related docs** | `09_UI_MVP_FLUTTER.md` (Task 3.5 — interruption handling, never implemented), `11_IPHONE_AUDIO_CONVERSION.md`, `25/26_RESUMABLE_UPLOAD_*.md`, `21_SESSION_STATUS_PROPAGATION_AND_FAILURE_SEMANTICS.md` |

---

## 1. Bug report

> *"Session (recording) was lost when a phone call arrived during the recording of the session."*

A therapist records a session, an incoming phone call interrupts it, and afterwards
the session is gone — either the remainder of the session is silently missing from
the audio, or (when the app was killed while backgrounded during the call) the whole
recording disappears with no trace in the app.

This is the worst failure class the product has: **unrecoverable loss of a 60–90 min
clinical session** that cannot be re-recorded. P1 ("zero data loss") currently holds
from the moment `runner.enqueue()` is called, but is entirely violated for the window
**between `RecordingService.start()` and `_finishAndUpload()`** — i.e. for the whole
duration of the session itself.

---

## 2. Root-cause analysis

Recording stack: `record: ^6.2.0` → resolved `record_ios 1.2.0` / `record_android 1.5.1`.
The app records FLAC @ 16 kHz mono via `AVAudioRecorder` (iOS) / `AudioRecord` thread
(Android) into `<docs>/sessions/<sessionId>/raw.flac`.

### 2.1 What the plugin does on an interruption (verified in plugin source)

`RecordConfig.audioInterruption` defaults to `AudioInterruptionMode.pause` — the app
passes no override in `recording_service.dart:101-111`, so we run in `pause` mode.

* **iOS** — `record_ios/.../RecorderSessionExtension.swift:60-85` subscribes to
  `AVAudioSession.interruptionNotification`:
  * `.began` (call arrives) → native `pause()` → emits `RecordState.pause` to Dart.
  * `.ended` → in `pause` mode: **nothing**. The recorder stays paused forever.
    (Only `pauseResume` mode calls `setActive(true)` + `resume()`.)
* **iOS** — native `resume()` (`RecorderFileDelegate.swift`) is literally
  `audioRecorder?.record()`: it does **not** reactivate the `AVAudioSession`
  (deactivated by the call) and **discards the Bool result**. After a call, a resume
  attempt can silently fail — the app believes it's recording, nothing is captured.
* **Android** — `record_android/.../AudioRecorder.kt`: `AUDIOFOCUS_LOSS*` →
  `pauseRecording()`; resume only in `PAUSE_RESUME` mode. Same shape.

### 2.2 What our app layer does about it: nothing

1. **State desync.** `RecordingService` never subscribes to
   `AudioRecorder.onStateChanged()`. When the plugin natively pauses, the service's
   own `_state` stays `recording`, the 200 ms ticker keeps accruing
   `currentDuration` (`recording_service.dart:54-60`), the UI keeps showing the
   pulsing "recording" indicator and the counter keeps climbing. The therapist has
   **no signal whatsoever** that capture stopped.
2. **No resume path.** Nothing handles interruption-ended. `docs/09` Task 3.5
   specified "auto-pause on interruption + manual resume prompt" — it was never
   implemented (no `interruption`/`audiofocus`/`onStateChanged` reference exists
   anywhere under `lib/`, `ios/Runner/`, or `android/app/src/`).
3. **Untrustworthy resume.** Even when the user happens to tap pause→resume after a
   call, `RecordingService.resume()` (`recording_service.dart:132-137`) calls the
   broken native resume described above and *assumes success*. Ditto the
   resume-before-stop guard in `stop()` (`recording_service.dart:148-161`).
4. **Total-loss path: app killed during the call.** Answering a call backgrounds the
   app and interrupts its audio session; with the recorder paused, the
   `UIBackgroundModes: audio` entitlement (`ios/Runner/Info.plist:60-65`) no longer
   keeps the process alive → iOS may suspend then terminate it (long call, memory
   pressure). On Android it's worse: the manifest declares
   `FOREGROUND_SERVICE_MICROPHONE` *permission* but **no service exists**, so the OS
   will kill a backgrounded recording app readily. When the process dies:
   * the partial `raw.flac` **survives on disk** (`AVAudioRecorder` writes
     incrementally), but
   * the recording enters the durable Hive upload queue only at stop time inside
     `_finishAndUpload` (`recording_screen.dart:475-538`); session metadata
     (`patientFileId`, `therapistId`, `reportLanguage`) lives only in widget state;
     and **nothing scans `<docs>/sessions/` at startup**. The only two references to
     that directory in the codebase are the writer (`recording_service.dart:87`) and
     the stop-time enqueue (`recording_screen.dart:479`).
   * → the file is orphaned forever; from the therapist's perspective the session
     vanished. **This is the reported bug.**
5. **Duration lie.** Because the ticker keeps counting through the call,
   `actualDurationSeconds` sent to the backend includes the un-recorded gap.

### 2.3 Failure-mode matrix (current behavior)

| Scenario | Audio before call | Audio after call | Session visible afterwards |
|---|---|---|---|
| Call **declined**, app stayed foreground | kept | **lost silently** (recorder paused, UI says recording) | yes, but truncated at call time |
| Call **answered**, short, app resumed | kept | **lost silently** (resume never happens / silently fails) | yes, but truncated |
| Call **answered**, long → OS kills app | kept **on disk only** | n/a | **NO — total loss (the bug)** |
| Alarm / Siri / other interruption | same as above | same | same |

---

## 3. Design goals

* **G1 — Zero total loss.** From the first second of capture, a process kill at any
  moment must leave enough durable state to recover the partial recording and offer
  it for upload on next launch. (Extends P1 to the recording window.)
* **G2 — No silent gaps.** The therapist must *see* within ~1 s that recording was
  interrupted, and the timer must stop counting. Resume must be explicit and
  **verified** — never assumed.
* **G3 — Honest metadata.** `actualDurationSeconds` reflects captured audio (or a
  best-effort estimate clearly derived), not wall-clock.
* **G4 — Match docs/09 UX intent.** Auto-pause on interruption; **manual** resume by
  the therapist (they may deliberately want to keep it paused). We do *not* switch
  the plugin to `pauseResume` auto-resume — rationale in §9 R2.
* **Non-goals (this fix):** background-recording hardening beyond interruption
  recovery; multi-segment file stitching; Android foreground service (deferred to
  phase 2, §7.5); plugin fork/upstream PR (tracked as follow-up).

---

## 4. Solution overview — five workstreams

| WS | Title | Fixes | Risk | Size |
|---|---|---|---|---|
| **WS1** | Recording manifest + orphan recovery on launch | §2.2-4 (total loss) | low | M |
| **WS2** | Native state sync (`onStateChanged`) + interrupted UI state | §2.2-1/2 (silent desync) | low | M |
| **WS3** | Trustworthy resume (iOS session reactivation channel + verification) | §2.2-3 | med | S |
| **WS4** | Duration honesty | §2.2-5 | low | XS |
| **WS5** | Android foreground service (phase 2, separate branch) | §2.2-4 Android leg | med | M |

WS1 is the safety net that makes every other failure mode survivable — implement it
first; it alone resolves the reported "lost session" symptom. WS2+WS3 fix the
day-to-day experience. WS1, WS2, WS3, WS4 ship together on
`fix/recording-call-interruption`.

---

## 5. Detailed design

### 5.1 WS1 — Recording manifest + orphan recovery

#### 5.1.1 Manifest file

New file written at recording start, deleted on successful enqueue or explicit
discard:

```
<docs>/sessions/<sessionId>/manifest.json
```

```json
{
  "version": 1,
  "sessionId": "5f0c…",
  "therapistId": "th_…",
  "patientFileId": "pf_…",
  "patientAlias": "Jan K.",
  "patientLanguageCode": "pl-PL",
  "startedAtUtc": "2026-06-09T10:12:33Z",
  "appBuild": "1.4.2+57"
}
```

Notes:
* `patientAlias` is denormalized into the manifest so the recovery sheet can render
  a human-readable label even if the patients cache is cold / the patient was
  deleted. Alias is already shown on the recording screen, so no new PHI exposure
  class — but see §9 R5 for at-rest considerations.
* `version` for forward-compat; unknown versions are ignored (file left in place).

#### 5.1.2 New module: `lib/services/recording_manifest_store.dart`

```dart
class RecordingManifest {
  // fields mirror the JSON above
  // toJson / fromJson with defensive parsing (same style as PendingUpload)
}

class RecordingManifestStore {
  /// <docs>/sessions/<sessionId>/manifest.json
  Future<void> write(RecordingManifest m);
  Future<void> delete(String sessionId);          // best-effort, idempotent
  /// Scans <docs>/sessions/*/manifest.json. Malformed JSON → skipped
  /// (never thrown), logged with debugPrint.
  Future<List<RecordingManifest>> scanAll();
}
```

Pure `dart:io` + `path_provider`, no Hive — the manifest must be co-located with
`raw.flac` so the pair lives or dies together, and must be writable before any
provider graph is up.

Provider in `lib/providers/services_provider.dart`:

```dart
final recordingManifestStoreProvider =
    Provider<RecordingManifestStore>((ref) => RecordingManifestStore());
```

#### 5.1.3 Write/delete lifecycle hooks

| Moment | Action | Where |
|---|---|---|
| right after `_service.start(sessionId)` succeeds | `write(manifest)` | `RecordingScreen._start()` (`recording_screen.dart:233-278`) — the screen owns the metadata (`patientFileId`, `therapistId`, `patientAlias`, `reportLanguage`); `RecordingService` stays metadata-free |
| right after `runner.enqueue(pending)` returns | `delete(sessionId)` — durability ownership transfers to the Hive queue row | `_finishAndUpload()` (`recording_screen.dart:538`) |
| user discards (`_discardAndPop`, "Usuń to nagranie bezpowrotnie", back-gesture confirm) | `delete(sessionId)` after `_service.cancel()` | `recording_screen.dart:283-314, 415-422` |
| recovery sheet "Usuń" | delete whole `<docs>/sessions/<sessionId>/` dir | recovery service (below) |

Ordering matters: manifest write happens *after* `start()` (mic permission may
fail), and manifest delete happens *after* enqueue (never before — a kill between
the two must leave at least one durable owner). A kill in the instant between
`start()` success and manifest write loses only ≤1 s of audio; the min-size filter
(§5.1.4) garbage-collects the stub dir.

`_finishAndUpload`'s offline branch (`sourceKind: encryptedChunks`, phase
`encrypting`) also deletes the manifest after enqueue — the queue row owns the
session dir from then on, and the recovery scanner must not double-offer it
(see skip-rule 1 below).

#### 5.1.4 New module: `lib/services/recording_recovery_service.dart`

```dart
class RecoverableRecording {
  final RecordingManifest manifest;
  final String flacPath;
  final int sizeBytes;
  final Duration estimatedDuration;   // see below
}

class RecordingRecoveryService {
  RecordingRecoveryService({
    required RecordingManifestStore store,
    required UploadQueueRunner runner,   // to check existing rows + enqueue
  });

  /// Returns orphans for [therapistId], applying the skip rules.
  Future<List<RecoverableRecording>> findOrphans(String therapistId);

  /// Enqueues the orphan as a plainFile upload and deletes the manifest.
  Future<void> recover(RecoverableRecording r);

  /// Deletes <docs>/sessions/<id>/ entirely.
  Future<void> discard(RecoverableRecording r);

  /// Housekeeping: delete orphan dirs older than 14 days, and orphans
  /// belonging to other therapists older than 14 days (multi-account
  /// device). PHI must not rot on disk indefinitely.
  Future<void> sweep(String therapistId);
}
```

**Skip rules in `findOrphans`** (each logged when triggered):

1. A `PendingUpload` row with `localId == sessionId` already exists in the queue
   (any phase) → the queue owns it; skip. (Query via `runner.snapshotNow()`.)
2. `manifest.sessionId == RecordingService.activeSessionId` → currently being
   recorded; skip. (New getter, §5.2.)
3. `raw.flac` missing or `< 256 KiB` (~15–20 s of 16 kHz mono FLAC) → not a
   meaningfully recoverable session; delete the dir, skip.
4. `manifest.therapistId != therapistId` → another account's PHI; never surface,
   leave for `sweep`.

**Duration estimate** (display + `actualDurationSeconds` metadata only):

```dart
// Primary: wall-clock — file mtime minus manifest.startedAtUtc.
// (mtime ≈ last byte flushed ≈ interruption moment.)
// Cross-check: FLAC bitrate bound — speech at 16 kHz mono FLAC runs
// ~10–18 KiB/s; sizeBytes / 14000 is a sane ceiling. Take:
final est = min(mtimeDelta, Duration(seconds: sizeBytes ~/ 9000));
// and clamp to kMaxSessionDuration.
```

Exact duration is recomputed server-side from the audio during transcription; this
estimate only needs to be the right order of magnitude (see §9 R4 re billing).

**`recover()`** builds the row exactly like the online stop-path
(`recording_screen.dart:500-514`):

```dart
final pending = PendingUpload.initial(
  localId: r.manifest.sessionId,
  therapistId: r.manifest.therapistId,
  patientFileId: r.manifest.patientFileId,
  patientLanguageCode: r.manifest.patientLanguageCode,
  sourceKind: UploadSourceKind.plainFile,
  sourcePath: r.flacPath,
  contentType: 'audio/flac',
  sizeBytes: r.sizeBytes,
  chunkCount: 1,
  actualDurationSeconds: r.estimatedDuration.inSeconds,
  needsServerSideConversion: false,
  idempotencyKey: r.manifest.sessionId,   // same idempotency contract
  now: DateTime.now().toUtc(),
);
await runner.enqueue(pending);
await store.delete(r.manifest.sessionId);
unawaited(runner.kick());
```

Reusing `sessionId` as `idempotencyKey` means a recovery retried after a mid-enqueue
kill cannot create a duplicate `audio_uploads` row server-side — same contract the
normal path relies on.

*Unfinalized-FLAC caveat:* a kill mid-write leaves a FLAC whose STREAMINFO header
has `total_samples = 0`. FLAC is frame-synced, so decoders (ffmpeg, and per spec
Chirp's decoder) handle it as a streaming input. **Must be verified e2e** (§8.3
case M7). Fallback if Chirp rejects it: set `needsServerSideConversion: true` for
recovered rows to force the existing server-side ffmpeg transcode
(docs/11), which definitively re-containers the audio. Decide based on M7 evidence
before merge.

#### 5.1.5 Trigger point + recovery UI

* Provider: `lib/providers/recording_recovery_provider.dart` —
  `FutureProvider<List<RecoverableRecording>>` that awaits
  `uploadQueueRunnerProvider` + `currentUserProvider` and runs
  `sweep()` then `findOrphans()`. Guarded by a module-level `bool _ranThisLaunch`
  (same singleton-holder idiom as `upload_queue_provider.dart`) so it runs once per
  cold launch.
* Hook: `HomeScreenV2.initState` → `addPostFrameCallback` → read the provider; if
  non-empty, show one `EuphireActionSheet` per orphan (sequentially; in practice
  there will be ≤1).

Sheet spec (all strings via l10n, §6):

```
header: "Znaleziono przerwane nagranie"
body:   "Nagranie sesji z {patientAlias} z {date} ({estMinutes} min) nie
         zostało wysłane — prawdopodobnie aplikacja została przerwana
         w trakcie nagrywania. Co chcesz zrobić?"
primary:     "Wyślij do analizy"   → recover(); SnackBar "Nagranie w kolejce
                                      wysyłki" (queue pill picks it up — the
                                      existing pending-uploads UI tracks it)
secondary:   "Zdecyduję później"   → dismiss; manifest stays; re-prompt next
                                      cold launch (≤ 14 days, then sweep)
destructive: "Usuń nagranie"       → second confirm sheet
                                      (header "Usunąć bezpowrotnie?",
                                       destructive "Usuń", secondary "Anuluj")
                                      → discard()
```

`isDismissible: false` (same as the existing max-duration sheet) — a swipe-away is
treated as "later", not as a decision.

Analytics (existing `analyticsCollectorProvider` patterns):
`recording.orphan_found {est_duration_seconds, size_bytes, age_hours}`,
`recording.orphan_recovered`, `recording.orphan_discarded`,
`recording.orphan_postponed`.

### 5.2 WS2 — Native state sync + interrupted UI state

#### 5.2.1 `RecordingService` changes (`lib/services/recording_service.dart`)

1. **DI for testability** (constructor injection; default keeps production wiring):

   ```dart
   RecordingService({AudioRecorder? recorder})
       : _recorder = recorder ?? AudioRecorder();
   ```

2. **New state** in the enum:

   ```dart
   enum RecordingState { idle, recording, paused, interrupted, stopped, error }
   ```

   `interrupted` ≡ "paused by the OS, not by the user". Distinct from `paused` so
   the UI can render the warning banner and analytics can distinguish causes.

3. **Subscribe to the plugin state stream** (in the constructor, torn down in
   `dispose()`):

   ```dart
   _nativeSub = _recorder.onStateChanged().listen(_onNativeState);
   ```

4. **Intent flags** so self-caused events aren't misread as interruptions:
   `pause()` sets `_pauseRequested = true` before calling `_recorder.pause()`;
   `resume()`/`stop()`/`cancel()` set equivalent flags. Each flag is consumed
   (reset) by the matching native event, with a 2 s staleness timeout as a
   safety valve against a dropped event.

5. **Event reconciliation:**

   | Native event | Dart state | Action |
   |---|---|---|
   | `RecordState.pause`, `_pauseRequested` | recording | consume flag → `paused` (normal) |
   | `RecordState.pause`, no flag | recording | **interruption**: fold segment into `_accumulated`, `_segmentStart = null`, → `interrupted` |
   | `RecordState.record`, no flag | paused / interrupted | external resume (e.g. future plugin behavior): `_segmentStart = now`, → `recording` |
   | `RecordState.stop`, no flag | recording / paused / interrupted | unexpected native stop (plugin failure path): fold duration, keep `_activeFilePath`, → `error`; screen shows recovery guidance — the on-disk file remains recoverable via WS1 on next launch, or immediately via the stop path |
   | anything else | — | log only |

6. **`activeSessionId`** — new `String? get activeSessionId`, set in `start()`,
   cleared in `stop()`/`cancel()`. Used by the recovery scanner skip-rule 2.

7. **Reconcile-on-foreground** — events can be missed while the Flutter isolate is
   suspended during the call. New method, called by the screen's lifecycle
   observer:

   ```dart
   Future<void> reconcileWithNative() async {
     if (_state != RecordingState.recording) return;
     final rec = await _recorder.isRecording();
     if (!rec) {
       // missed the pause event while suspended
       _foldSegment();
       _setState(RecordingState.interrupted);
     }
   }
   ```

#### 5.2.2 `RecordingScreen` changes (`lib/screens/recording_screen.dart`)

1. Mix in `WidgetsBindingObserver`; on `AppLifecycleState.resumed` →
   `_service.reconcileWithNative()`.
2. **Interruption banner** — when `_recState == interrupted`, render above the
   `EuphireRecordingIndicator`: warning-styled card (ember border), icon
   `phone_paused_rounded`, text `recording_interrupted_banner_title` /
   `_body`, and the control panel switches to a single prominent resume button
   (`recording_interrupted_resume`). The duration counter freezes (it already will
   — ticker only adds time in `recording` state — but now the *displayed* state is
   honest too).
3. `_ControlPanel` gains the `interrupted` case: play button (resume) + stop
   button. Back-gesture guard (`_confirmDiscardOnBack`, `canPop`) updated to treat
   `interrupted` like `paused` (a discardable in-progress session — confirm before
   pop).
4. The `< 5 min` stop guard, confirm-end sheet, and max-duration sheet all treat
   `interrupted` like `paused` (no behavior change needed beyond enum exhaustiveness
   — Dart switch exhaustiveness will flag every site; fix each deliberately).
5. Analytics: `recording.interrupted {at_seconds}`,
   `recording.interruption_resumed {gap_seconds}`,
   `recording.interruption_resume_failed`.

### 5.3 WS3 — Trustworthy resume

#### 5.3.1 iOS native helper: `ios/Runner/AudioSessionHelper.swift`

Tiny MethodChannel, registered in `AppDelegate.didInitializeImplicitFlutterEngine`
next to the existing `AudioConverter` registration (`AppDelegate.swift:20-22` —
established pattern):

```swift
import AVFoundation
import Flutter

class AudioSessionHelper {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "superwizor/audio_session", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "reactivate":
        do {
          try AVAudioSession.sharedInstance()
            .setActive(true, options: .notifyOthersOnDeactivation)
          result(true)
        } catch {
          result(FlutterError(code: "reactivate_failed",
                              message: error.localizedDescription,
                              details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
```

Dart side: `lib/services/audio_session_helper.dart` — static wrapper, returns
`false` on any `PlatformException`/`MissingPluginException` (Android/macOS no-op:
Android focus re-grab is handled inside `record_android`'s own resume path).

#### 5.3.2 Verified resume protocol (`RecordingService.resume()`)

> **Implementation note (changed from the original draft):** during
> implementation we verified in plugin source that `Recorder.swift`'s
> `resume()` sets `m_state = .record` **unconditionally** after the
> (result-discarded) `audioRecorder?.record()` call — so the plugin's
> `isRecording()` and its state stream are *optimistic mirrors of intent*,
> not evidence of capture. The only platform-neutral signal that survives
> this is **bytes hitting the output file**: the service probes
> `File(activeFilePath).length()` across a ~1.2 s window
> (`captureProbeWindow`; 16 kHz mono FLAC writes ~10–18 KiB/s, flushed
> well within it) and reports success iff the file grew. The probe runs
> only on resumes from `interrupted` — a normal user pause never
> deactivated the session, so it keeps the instant fast path. The
> `AudioSessionHelper.reactivate()` result acts as a fast-fail gate
> before the probe (a still-active call makes `setActive(true)` throw
> with `insufficientPriority`).

```dart
/// Returns true iff capture verifiably restarted.
Future<bool> resume() async {
  if (_state != RecordingState.paused &&
      _state != RecordingState.interrupted) return false;
  final fromInterruption = _state == RecordingState.interrupted;
  if (!kIsWeb && Platform.isIOS) {
    final reactivated = await AudioSessionHelper.reactivate();
    if (!reactivated && fromInterruption) return false; // call still owns audio
  }
  _arm(RecordState.record);                  // intent: swallow our own event
  await _recorder.resume();
  if (fromInterruption && !await _verifyCapture()) {   // file-growth probe
    _setState(RecordingState.interrupted);   // stay honest
    return false;
  }
  _segmentStart = DateTime.now();
  _setState(RecordingState.recording);
  return true;
}
```

Callers updated to check the result:
* `_ControlPanel` resume tap and the banner's resume button → on `false`, sheet
  `recording_resume_failed_header/body` ("Nie udało się wznowić nagrywania.
  Dotychczasowe nagranie jest bezpieczne — możesz zakończyć sesję i wysłać je do
  analizy.") with primary = "Zakończ i wyślij" (`_onStopPressed` path) and
  secondary = "Spróbuj ponownie".
* Confirm-end sheet's "Wróć do nagrywania" (`recording_screen.dart:366-371`) —
  same failure handling.

#### 5.3.3 Stop-guard hardening (`RecordingService.stop()`)

The existing resume-before-stop guard (`recording_service.dart:152-161`) gains the
session reactivation and covers `interrupted`:

```dart
if (_state == RecordingState.paused || _state == RecordingState.interrupted) {
  if (!kIsWeb && Platform.isIOS) await AudioSessionHelper.reactivate();
  try {
    await _recorder.resume();
    await Future<void>.delayed(const Duration(milliseconds: 200));
  } catch (_) {/* best-effort; AVAudioRecorder.stop() still finalizes
                  the pre-pause content for FLAC */}
}
```

(The 0-byte-on-stop-from-paused failure was observed on the OGG path; FLAC via
`AVAudioRecorder` finalizes cleanly, but the guard is kept as cheap insurance and
now actually works post-call.)

### 5.4 WS4 — Duration honesty

Mostly falls out of WS2 (segment folding on the native pause event stops the
clock during the call). Additionally:

* `_finishAndUpload` switches `actualDurationSeconds` from `_displayDuration`
  (UI-stream copy) to `_service.currentDuration` (source of truth) at
  `recording_screen.dart:510, 528`.
* The max-duration check (`recording_screen.dart:247-253`) is unaffected — the
  ticker only emits while `recording`.

### 5.5 WS5 — Android foreground service (IMPLEMENTED)

The `record` plugin manages Android audio focus but NOT a foreground service, so
an extended backgrounding (long phone call, memory pressure) lets the OS kill the
recording process. A microphone-type foreground service keeps it alive.

**Native** — `android/.../RecordingForegroundService.kt`: a `Service` that calls
`startForeground` with `FOREGROUND_SERVICE_TYPE_MICROPHONE` (API 30+; plain
`startForeground` below that) and a low-importance, ongoing notification carrying a
tap-to-reopen `PendingIntent`. `START_NOT_STICKY` — a resurrected service with no
recorder behind it would be a phantom "recording" notification; WS1's orphan scan
is the recovery path instead. `MainActivity.kt` registers the
`superwizor/recording_fgs` MethodChannel (`start{title,body}` / `stop`).

**Manifest** — `<service android:foregroundServiceType="microphone" />`,
`FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MICROPHONE` (already present) +
`POST_NOTIFICATIONS` (Android 13+, for the notification to be visible — the service
runs regardless).

**Dart** — `lib/services/recording_foreground_service.dart`: best-effort
start/stop, Android-only (`!kIsWeb && Platform.isAndroid`), swallows every error so
a foreground-service hiccup can never abort a recording. `RecordingService.start`
brings it up (notification strings threaded from the l10n pipeline —
`recording_fgs_notification_title`/`_body` — so the system notification respects the
user's locale; Kotlin has Polish-primary fallbacks); `stop()`, `cancel()`, and the
unexpected-native-stop path all tear it down.

**Notes.** WS1's manifest/recovery already covered the Android total-loss path, so
this is defense-in-depth that lets a backgrounded Android session *survive* the call
rather than rely on post-hoc recovery. The runtime `POST_NOTIFICATIONS` request is
not wired (the service is unaffected; only the notification's visibility is) — a
small follow-up if Android UX wants the prompt.

---

## 6. l10n keys

Per the hard rule (zero hardcoded UI strings — `l10n.yaml`), add to `app_pl.arb`
(template) + `app_en.arb`. Note: several existing sheets in `recording_screen.dart`
("Brak zgody", "Błąd mikrofonu", "Błąd uploadu"…) violate the rule today — do not
fix them in this branch (scope), but don't add new violations.

| Key | PL | EN |
|---|---|---|
| `recording_interrupted_banner_title` | `Nagrywanie wstrzymane` | `Recording paused` |
| `recording_interrupted_banner_body` | `Połączenie lub inna aplikacja przerwała nagrywanie. Dotychczasowe nagranie jest bezpieczne.` | `A phone call or another app interrupted the recording. Everything captured so far is safe.` |
| `recording_interrupted_resume` | `Wznów nagrywanie` | `Resume recording` |
| `recording_resume_failed_header` | `Nie udało się wznowić` | `Could not resume` |
| `recording_resume_failed_body` | `Nie udało się wznowić nagrywania. Dotychczasowe nagranie jest bezpieczne — możesz zakończyć sesję i wysłać je do analizy.` | `Recording could not be resumed. Everything captured so far is safe — you can end the session and send it for analysis.` |
| `recording_resume_failed_retry` | `Spróbuj ponownie` | `Try again` |
| `recording_resume_failed_finish` | `Zakończ i wyślij` | `Finish and send` |
| `recovery_sheet_header` | `Znaleziono przerwane nagranie` | `Interrupted recording found` |
| `recovery_sheet_body` (placeholders `patientAlias`, `date`, `minutes`) | `Nagranie sesji z {patientAlias} z {date} (ok. {minutes} min) nie zostało wysłane — aplikacja została przerwana w trakcie nagrywania. Co chcesz zrobić?` | `The session recording for {patientAlias} from {date} (~{minutes} min) was never sent — the app was interrupted while recording. What would you like to do?` |
| `recovery_sheet_send` | `Wyślij do analizy` | `Send for analysis` |
| `recovery_sheet_later` | `Zdecyduję później` | `Decide later` |
| `recovery_sheet_delete` | `Usuń nagranie` | `Delete recording` |
| `recovery_delete_confirm_header` | `Usunąć bezpowrotnie?` | `Delete permanently?` |
| `recovery_delete_confirm_body` | `Tego nagrania nie da się odzyskać.` | `This recording cannot be recovered.` |
| `recovery_enqueued_snackbar` | `Nagranie dodane do kolejki wysyłki` | `Recording added to the upload queue` |

Run `flutter gen-l10n` after editing.

---

## 7. File-change inventory

| File | Change |
|---|---|
| `lib/services/recording_service.dart` | DI ctor; `interrupted` state; `onStateChanged` subscription + reconciliation table; intent flags; verified `resume() → bool`; `reconcileWithNative()`; `activeSessionId`; hardened stop-guard |
| `lib/services/recording_manifest_store.dart` | **new** — manifest model + store |
| `lib/services/recording_recovery_service.dart` | **new** — scan/skip-rules/recover/discard/sweep; recovered rows use `audio/x-flac` to force server re-encode (R1) |
| `lib/services/audio_session_helper.dart` | **new** — MethodChannel wrapper |
| `lib/services/recording_foreground_service.dart` | **new (WS5)** — Android FGS control wrapper |
| `android/.../RecordingForegroundService.kt` | **new (WS5)** — microphone foreground service + notification |
| `android/.../MainActivity.kt` | register `superwizor/recording_fgs` channel |
| `android/app/src/main/AndroidManifest.xml` | `<service microphone>` + `POST_NOTIFICATIONS` |
| `superwizor-backend/.../storage/converter_test.go` | guard test: `IsChirpSupported("audio/x-flac") == false` (R1 coupling) |
| `lib/providers/services_provider.dart` | providers for the two new services |
| `lib/providers/recording_recovery_provider.dart` | **new** — once-per-launch orphan future |
| `lib/screens/recording_screen.dart` | manifest write/delete hooks; lifecycle observer; interruption banner; `interrupted` in control panel/pop-guard/sheets; resume-failure sheet; `actualDurationSeconds` source |
| `lib/screens/home_screen_v2.dart` | post-frame recovery prompt |
| `ios/Runner/AudioSessionHelper.swift` | **new** — `reactivate` channel |
| `ios/Runner/AppDelegate.swift` | register AudioSessionHelper |
| `lib/l10n/app_pl.arb`, `app_en.arb` | §6 keys |
| `test/…` | §8 |

---

## 8. Test plan

### 8.1 Unit tests (new)

* `test/services/recording_manifest_store_test.dart` — round-trip, malformed JSON
  skipped, delete idempotent (temp dirs via `setUp`).
* `test/services/recording_recovery_service_test.dart` — each skip rule (queue row
  exists / active session / undersized file / foreign therapist); duration
  estimate (mtime vs size-bound, clamping); `recover()` builds the exact
  `PendingUpload` shape (golden-compare `toJson`); `sweep()` age + foreign-orphan
  behavior. `UploadQueueRunner` faked behind a minimal interface or the existing
  test seams in `test/uploads/`.
* `test/services/recording_service_test.dart` — with injected fake `AudioRecorder`:
  unexpected native pause → `interrupted` + duration frozen; flagged pause →
  `paused`; resume verification failure → stays `interrupted`, returns false;
  unexpected native stop → `error`, `activeFilePath` retained;
  `reconcileWithNative` flips a stale `recording`.

### 8.2 Widget tests

* `interrupted` state renders banner + resume CTA; counter static.
* Recovery sheet: three actions wired; delete requires the second confirm.

### 8.3 On-device manual matrix (iPhone, physical device — interruptions cannot be
simulated faithfully)

Per CLAUDE.md "proof before passing": each case gets a screenshot/log under
`evidence/fix-recording-call-interruption/<case>/`, opened with Read and verified.

| # | Case | Expected |
|---|---|---|
| M1 | Record 2 min → incoming call → **decline** | banner ≤1 s after ring, counter frozen; resume works; final FLAC contains pre+post audio; gap absent from duration |
| M2 | Record 2 min → **answer**, talk 1 min, hang up, return to app | banner; resume (with reactivation) verifiably works; file intact |
| M3 | M2 but app **backgrounded** during call, return after 5 min | `reconcileWithNative` shows `interrupted` on return; resume works |
| M4 | Record 2 min → answer call → **force-kill app** during call → relaunch | recovery sheet appears with correct alias/date/~duration; "Wyślij do analizy" → row in queue pill → session reaches `done` end-to-end |
| M5 | M4 but choose "Zdecyduję później" → relaunch again | re-prompted; then "Usuń" + confirm → dir gone |
| M6 | Alarm-clock interruption (timer firing) | same as M1 |
| M7 | **Unfinalized-FLAC e2e**: kill mid-recording, recover, full pipeline | Chirp transcribes the partial FLAC; if rejected → flip recovered rows to `needsServerSideConversion: true` and retest (decision gate before merge, §5.1.4) |
| M8 | Regression: normal record → pause → resume → stop → upload | unchanged behavior |
| M9 | Regression: 130-min auto-cap sheet | unchanged |
| M10 | Discard paths (back-gesture, too-short destructive, confirm-end destructive) | manifest + dir deleted, no orphan prompt on relaunch |

### 8.4 Static gates

`flutter analyze` clean; `flutter test` green; `flutter gen-l10n` committed.

---

## 9. Risks & open questions

* **R1 — Unfinalized FLAC acceptance by Chirp. RESOLVED — forced server-side
  re-encode.** We no longer gamble on Chirp tolerating an unfinalized header. The
  recovery path uploads recovered FLAC under content-type **`audio/x-flac`** instead
  of `audio/flac`. The ingestion subscriber transcodes any source whose content-type
  is not in `IsChirpSupported` (converter.go), and `audio/x-flac` (a legitimate
  alternative FLAC MIME) is deliberately *not* in that list — so the bytes route
  through the server's lossless ffmpeg re-encode (`-c:a flac -ar 16000 -ac 1`), which
  rewrites a clean STREAMINFO header. The server's content-type→extension map
  defaults unknown types to `.flac`, so ffmpeg demuxes the real FLAC bytes correctly
  — a *mislabel* like `audio/mp4` would set a `.m4a` object path and break ffmpeg's
  demuxer, which is why `audio/x-flac` (truthful, `.flac` path) is the right lever.
  Zero backend/proto/schema change. The coupling is locked by a converter unit test
  asserting `IsChirpSupported("audio/x-flac") == false` with a comment pointing back
  here. (The local `needsServerSideConversion` bool is set `true` for observability
  but is never transmitted — the content-type is the actual server trigger.)
* **R2 — Why not `AudioInterruptionMode.pauseResume`?** It would auto-resume with
  native `setActive(true)` — but (a) docs/09 deliberately chose manual resume
  (therapist may be out of the room post-call; auto-resume records unintended,
  possibly un-consented audio — a privacy regression), (b) Apple does not guarantee
  `.ended` delivery (esp. if the app was suspended), so it can't be the only
  mechanism anyway, and (c) its failure path silently `stop()`s the recorder.
  Manual + verified resume + WS1 net is strictly more robust.
* **R3 — Plugin behavior drift.** The reconciliation table assumes
  `record_ios 1.2.0` / `record_android 1.5.1` event semantics (verified in source,
  §2.1). Pin with `record: 6.2.x` constraint and add a CHANGELOG-check note to
  `PROGRESS.md` for future upgrades. Follow-up: upstream issue for the discarded
  `record()` result + missing `setActive` in `resume()`.
* **R4 — `actualDurationSeconds` is an estimate for recovered rows.** Confirm with
  billing (docs/16/17) that reservation/settlement uses server-side measured
  duration, not the client hint. If the client value matters, bias the estimate
  low (size-bound only).
* **R5 — PHI at rest.** `raw.flac` + manifest sit unencrypted in Documents while
  orphaned (same exposure as today's recording window; iOS file protection
  `CompleteUntilFirstUserAuthentication` applies). The 14-day sweep bounds it.
  Post-MVP option: encrypt orphans with the existing `SecureAudioStorageService`
  chunk path during recovery instead of plainFile.
* **R6 — Multiple orphans / multi-account devices.** Sequential sheets handle >1;
  rule 4 + sweep handle foreign accounts. Both are edge-of-edge cases; logged.

---

## 10. Delivery plan (small commits, per repo conventions)

1. `fix: RecordingService DI + native state sync + interrupted state` (WS2 service
   layer + unit tests)
2. `feat: recording manifest store` (+ tests)
3. `feat: orphan recovery service + provider` (+ tests)
4. `feat: recovery prompt on home screen + l10n`
5. `feat: iOS AudioSessionHelper channel + verified resume` (WS3)
6. `fix: recording screen interruption banner + lifecycle reconcile + duration
   source` (WS2/WS4 UI)
7. `test: widget tests + evidence M1–M10`
8. `docs: PROGRESS.md + this doc status → IMPLEMENTED`

Merge gate: §8.4 green + M1–M10 evidence opened/verified + R1/R4 decisions
recorded in this doc.

## 11. Acceptance criteria

1. A phone call during recording is visibly surfaced within ~1 s; the timer stops;
   captured audio up to that point is never lost.
2. Resume after a call verifiably restarts capture, or fails *loudly* with a safe
   "finish and send" path.
3. Force-killing the app mid-recording loses at most the final ~1 s of audio; next
   launch offers the partial recording for upload, and that upload completes the
   full pipeline to a report.
4. Reported session duration excludes interruption gaps.
5. No regression in the normal record→pause→resume→stop→upload flow (M8–M10).
