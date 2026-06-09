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
          try AVAudioSession.sharedInstance()
            .setActive(true, options: .notifyOthersOnDeactivation)
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
