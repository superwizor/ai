import AVFoundation
import Flutter

/// MethodChannel `superwizor/audio_session` — see
/// lib/services/audio_session_helper.dart and docs/28 WS3.
///
/// A phone call deactivates our AVAudioSession; the `record` plugin's
/// resume() never re-activates it (and discards AVAudioRecorder.record()'s
/// Bool result), so post-call resumes silently capture nothing. This helper
/// lets Dart re-activate the session before resuming. `setActive(true)`
/// throwing (e.g. the call still owns audio) is reported as `false` so the
/// app can fail fast instead of pretending to record.
class AudioSessionHelper {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "superwizor/audio_session", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "reactivate":
        do {
          let session = AVAudioSession.sharedInstance()
          // FULL reconfiguration, not just activation (live-fix
          // 2026-07-23): a phone call — especially the SECOND one in a
          // session — resets the category/route, and the record
          // plugin's resume() never re-sets it (only start() does). A
          // bare setActive(true) then "succeeds" while the input route
          // stays dead: every capture probe fails forever (#57 on
          // device). Mirror the recording category before activating.
          try session.setCategory(
            .playAndRecord,
            options: [.defaultToSpeaker, .allowBluetoothHFP])
          try session.setActive(true, options: .notifyOthersOnDeactivation)
          result(true)
        } catch {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
