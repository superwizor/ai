---
type: System Documentation
title: "29. Investigation — Capturing Remote Sessions (Meet/Zoom/Teams) in the Web App"
description: "Status: Investigation / options analysis. No implementation yet. Scenario: Therapist on a desktop opens the Superwizor web app in a Chrome/Safari tab, presse..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/29_WEB_REMOTE_SESSION_CAPTURE_INVESTIGATION.md
tags: []
timestamp: 2026-06-10T18:50:54+02:00
---

# 29. Investigation — Capturing Remote Sessions (Meet/Zoom/Teams) in the Web App

**Status:** Investigation / options analysis. No implementation yet.
**Scenario:** Therapist on a desktop opens the Superwizor **web app** in a Chrome/Safari
tab, presses "record", then switches to another tab where the remote session runs
(Google Meet, Zoom, Teams). The Superwizor tab keeps recording **both sides** of the
conversation (remote participant = system/tab audio, therapist = microphone) in the
background, then feeds the existing upload → STT → analysis pipeline.

---

## 1. TL;DR / Recommendation

**It is implementable today as a pure web feature, but only on Chromium (Chrome/Edge),
and most reliably when the meeting itself runs in a browser tab.** The recommended
architecture is:

> `getUserMedia` (mic) + `getDisplayMedia` (meeting-tab audio; throwaway 1-px video
> track — the "one pixel" trick) → mix both in a `WebAudio` graph → `MediaRecorder`
> (`audio/webm;codecs=opus`, Chirp-native) → timeslice chunks buffered in IndexedDB →
> existing upload queue (resumable GCS upload, docs/26).

Safari cannot do this at all (no display-capture audio), Firefox neither — so the
feature must be **gated to Chromium** with a clear "open in Chrome" hint. Capturing
the **native** Zoom/Teams desktop apps (not a tab) additionally requires full-screen
sharing with system audio — fine on Windows, and on macOS only with Chrome 141+ on
macOS 14.2+. A meeting **bot** (option D) is the only browser-independent approach,
but it sends therapy audio through a third party (or heavy self-built infra) — a PHI
question before a technical one.

---

## 2. Hard platform facts (verified 2026-06)

| Capability | Chrome / Edge (Chromium) | Safari | Firefox |
|---|---|---|---|
| `getUserMedia` mic | ✅ | ✅ | ✅ |
| `getDisplayMedia` **tab** audio | ✅ (Chrome 74+, all OSes — user must tick **"Also share tab audio"** in the picker) | ❌ API exists, audio silently absent | ❌ audio ignored |
| `getDisplayMedia` **system** audio (full-screen share) | ✅ Windows; ✅ macOS only **Chrome 141+ AND macOS 14.2+** (OS-level gate; Apple only opened system-audio capture to apps in 14.2) | ❌ | ❌ |
| Audio-**only** display capture (`video:false`) | ❌ spec-mandated `TypeError` — a video track is compulsory | — | — |
| Keeps capturing when the capturing tab is backgrounded | ✅ audio path (WebAudio/MediaRecorder run on the audio thread; a tab with active capture is exempt from freezing). Canvas/video rendering *is* throttled — irrelevant for audio. | — | — |
| Mobile browsers | ❌ display-capture audio not supported (native app covers mobile anyway) | ❌ | ❌ |

Other load-bearing details:

- **The picker cannot be skipped or persisted.** `getDisplayMedia` requires a user
  gesture and a surface picker **every session** — by spec, as an anti-abuse measure.
  The therapist will always click "record" → pick the Meet/Zoom tab → tick "share tab
  audio". A "wrong choice" (no audio track on the returned stream) is detectable and
  we can re-prompt with instructions.
- **Tab audio keeps playing to the user** during `getDisplayMedia` capture (unlike
  extension `tabCapture`, which mutes the tab unless re-routed). There's even a
  `suppressLocalAudioPlayback` constraint — we leave it `false`.
- **The captured tab shows Chrome's "this tab is being shared" indicator** — a
  built-in consent/visibility signal, arguably a feature for a therapy product.
- `surfaceSwitching: 'include'` lets the therapist re-point the capture to a different
  tab mid-session without restarting the recording.

## 3. The "one pixel" trick, demystified

The spec **forbids audio-only** display capture: `getDisplayMedia({audio:true,
video:false})` rejects. Products that "capture audio with one pixel" all do the same
dance (documented in [w3c/mediacapture-screen-share#100](https://github.com/w3c/mediacapture-screen-share/issues/100)):

1. Request `{ video: { width: {ideal: 1}, height: {ideal: 1}, frameRate: {ideal: 1} },
   audio: { ... } }` — i.e. ask for a video track but constrain it to ~1 px @ 1 fps so
   it costs nothing.
2. The moment the stream arrives, **read the audio track and `stop()` (or just never
   consume) the video track.** In Chrome the audio track keeps flowing after the video
   track is stopped.
3. Record only the audio.

So "one pixel" is not a special API — it's *minimizing the mandatory video track*.
Two practical notes:

- Keep the stopped/ignored video track's existence in mind for UX copy: Chrome's
  sharing bar says "sharing a tab" even though we only use audio. Explain it in-app.
- An occasionally seen variant — a 1-px `<video>` element kept in the DOM playing the
  captured stream — exists to defeat *rendering* throttling for **video** use cases.
  For audio-only we don't need it: the WebAudio/recorder pipeline runs on the audio
  thread, which is not throttled while capture is active.

## 4. Options

### A. Pure web: tab-share + mic, mixed client-side ⭐ recommended core
- **How:** `getUserMedia({audio: {echoCancellation: true, ...}})` for the therapist +
  `getDisplayMedia` tab share with audio (one-pixel trick) for the remote side. Mix:
  two `MediaStreamAudioSourceNode`s → `MediaStreamAudioDestinationNode` →
  `MediaRecorder('audio/webm;codecs=opus', timeslice≈10s)`. Buffer every chunk into
  IndexedDB as it arrives (crash/reload-recoverable: a webm whose chunks are all
  present concatenates back into a valid file). On stop → hand to the upload queue.
- **Covers:** Meet always (browser-native); Zoom/Teams **when joined from the browser
  tab** ("join from browser" links — both products support it).
- **Pros:** No install, no extension review, no third party touching PHI, audio
  continues with the recorder tab in the background, fits the existing pipeline
  (`audio/webm` is already in `_kChirpNativeContentTypes` / `IsChirpSupported`).
- **Cons:** Chromium-only; picker friction each session; user can pick the wrong
  surface or forget the audio checkbox (detect + coach); does NOT capture native
  Zoom/Teams apps.

### B. Full-screen + system audio (extension of A, for native apps)
- Same pipeline, but the picker choice is "Entire screen" + "Share system audio".
  Captures **everything** the machine plays — including the native Zoom/Teams clients.
- **Windows:** works on any recent Chrome. **macOS:** Chrome 141+ on macOS 14.2+ only.
  Older Macs → not available; fall back to "join from browser".
- Offer it as the in-app fallback path when the therapist says the session is in a
  native app. Same code; only the picker guidance differs.

### C. Chrome extension (`chrome.tabCapture` + offscreen document)
- An extension can capture a chosen tab's audio **without the per-session picker**,
  record in an offscreen document (survives service-worker suspension), and hand the
  file to the web app.
- **Pros:** Slickest repeat-use UX; most robust background behavior; this is how the
  commercial "meeting recorder" extensions (Meetgeek, ScreenApp, …) work.
- **Cons:** A second deliverable (Chrome Web Store listing + review + permissions
  policy), still Chromium-only, still browser-tab-only (no native apps), `tabCapture`
  mutes the tab unless you re-route audio through an `AudioContext`. **Not worth it
  for v1** — revisit only if picker friction proves to be a real adoption blocker.

### D. Meeting bot (Recall.ai-style, or self-built)
- A server-side participant joins the Meet/Zoom/Teams call and records both sides.
- **Pros:** Browser/OS-independent, works with native apps, captures clean per-side
  audio, visibly present in the call (consent transparency).
- **Cons:** **Therapy audio flows through a third party** (or a substantial self-built
  bot fleet) — GDPR/PHI processing agreement needed; per-minute cost; meeting-platform
  ToS/abuse surface; a much bigger project. Park unless the web-capture path fails in
  the field.

### E. Desktop app with audio loopback / virtual audio device
- Electron/Flutter-desktop with native loopback, or asking therapists to install
  BlackHole/VB-Cable. Rejected: the whole point is "no install"; virtual audio
  devices are far beyond the target users.

## 5. Flutter-web integration sketch (for option A/B)

None of this is exposed by the Flutter plugins the app already uses (`record` does mic
only on web), so it's a small **JS-interop layer** (`dart:js_interop` + `package:web`,
or a ~150-line `capture_shim.js`):

1. `startRemoteCapture()` → does the `getUserMedia` + `getDisplayMedia` + WebAudio mix
   + `MediaRecorder` dance; emits `ondataavailable` chunks and state events
   (audio-track-missing, surface-ended, etc.) to Dart.
2. Dart side: a `kIsWeb`-gated `RemoteSessionRecorder` that mirrors the existing
   `recording_service.dart` contract — so `new_session_screen` / the upload queue
   don't care where the bytes came from. Chunks land in IndexedDB (web's analogue of
   the staged-file durability we have on mobile; the "skip encryption when uploading
   online" path already exists).
3. Stop → assemble blob → enqueue as `plainFile`-equivalent (`audio/webm`, known
   duration from the recorder clock) → **web upload path**.
4. UI: a "Sesja zdalna (online)" entry next to record/upload; guided picker copy
   ("wybierz kartę spotkania i zaznacz *Udostępnij dźwięk karty*"); detect missing
   audio track → re-prompt; live level meter so the therapist trusts it's capturing;
   optionally a Document Picture-in-Picture mini-window with the recording timer +
   stop button that stays visible while they're in the Meet tab.

**Dependency — web upload is currently deferred** (`docs/agents/12`): the web app has
no working upload backend path (ingestion is raw gRPC, unreachable from browsers).
This feature *requires* un-deferring it. The good news: the resumable-upload work
(docs/26) made the server half browser-ready — `CreateAudioUpload` needs a
Connect/gRPC-web exposure (or a thin HTTP facade), and the GCS bucket CORS change is
already specced in docs/26 §PR1 (`Content-Range`/`Range`/`Location`/`x-goog-resumable`
headers). The browser can then drive the same resumable chunk protocol the mobile app
now uses.

Sizing: ~90-min session @ opus 64 kbps ≈ 45 MB — comfortably inside the existing
130-min/upload-size envelope.

## 6. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Therapist forgets "share tab audio" checkbox | Stream returns no audio track → detect immediately, stop, show annotated screenshot of the picker, retry. |
| Therapist closes/shares the wrong tab, or closes the meeting tab mid-call | Listen to the display track's `onended` + `surfaceSwitching:'include'`; surface a "recording lost the meeting tab" banner + quick re-pick. |
| Recorder tab discarded by the browser | Tabs with active capture aren't frozen/discarded; additionally hold the mic stream open and keep a service-worker-independent IndexedDB chunk trail so even a crash loses ≤ timeslice seconds. |
| Echo / remote voice double-captured via speakers | `echoCancellation:true` on the mic track; recommend headphones in the UX copy. |
| Safari/Firefox users | Feature-gate with capability detection (`navigator.mediaDevices.getDisplayMedia` + Chromium UA hint); show "use Chrome/Edge for remote-session recording". |
| Native Zoom/Teams app | Path B (screen+system audio) on Windows & new macOS; otherwise instruct "join from browser". |
| Legal/consent | Existing per-patient recording-consent flag applies; Chrome's sharing indicator adds visibility. Recording a call both sides = same consent obligations as in-office recording (therapist's responsibility, as today). |

## 7. Suggested phasing (when picked up)

1. **Spike (1–2 d):** static HTML page proving tab-audio + mic mix → webm → playback,
   incl. background-tab soak test (60+ min) on macOS + Windows Chrome.
2. **Web upload un-defer (prereq):** Connect-web exposure for `CreateAudioUpload` +
   bucket CORS (docs/26 §PR1 list) + browser resumable PUT loop.
3. **Feature:** JS shim + Dart `RemoteSessionRecorder` + "Sesja zdalna" UI + IndexedDB
   durability + pickup of existing queue UX (progress bar etc.).
4. **Field test:** real Meet + Zoom-in-browser sessions; verify STT/diarization on
   mixed-source audio; then decide whether picker friction warrants option C.

## 8. Sources

- [MDN — getDisplayMedia()](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getDisplayMedia)
- [caniuse — getDisplayMedia audio capture support](https://caniuse.com/mdn-api_mediadevices_getdisplaymedia_audio_capture_support)
- [addpipe — getDisplayMedia demo & support matrix](https://addpipe.com/getdisplaymedia-demo/)
- [addpipe — system sounds on Chrome on macOS (Chrome 141 / macOS 14.2)](https://blog.addpipe.com/getdisplaymedia-allows-capturing-the-screen-with-system-sounds-on-chrome-on-macos/)
- [w3c/mediacapture-screen-share#100 — audio-only capture forbidden / workaround](https://github.com/w3c/mediacapture-screen-share/issues/100)
- [Screen Capture spec](https://w3c.github.io/mediacapture-screen-share/)
- [Chrome extensions — tabCapture + offscreen recording](https://developer.chrome.com/docs/extensions/reference/api/tabCapture)
- [Recall.ai — building a Chrome recording extension (tabCapture/offscreen patterns)](https://www.recall.ai/blog/how-to-build-a-chrome-recording-extension)
- [Firefox — getDisplayMedia audio capture not implemented](https://bugzilla.mozilla.org/show_bug.cgi?id=1541425)
