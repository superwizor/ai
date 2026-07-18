import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Cold-start cleanup: dismiss any Live Activities orphaned from a
    // previous app session. If the app was killed while the pipeline was
    // running, the widget would be stuck on the last status forever.
    // Cleaning on launch is safe because the user is opening the app
    // and will see session state in the UI directly.
    if #available(iOS 16.2, *) {
      LiveActivityManager.shared.cleanupOrphaned()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // ── Native push handler for Live Activity ────────────────────────
  //
  // FCM silent/data pushes arrive here BEFORE reaching the Dart side.
  // This is critical because the Dart background handler runs in a
  // SEPARATE isolate whose FlutterEngine does NOT have our
  // MethodChannel registered — so MethodChannel calls from Dart bg
  // would silently fail (MissingPluginException, caught by try/catch).
  //
  // By handling it natively we bypass that limitation entirely.
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    if #available(iOS 16.2, *) {
      handleLiveActivityPush(userInfo)
    }
    // Always forward to super so Firebase Messaging / Flutter still
    // processes the notification normally (Dart handlers, etc.).
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }

  @available(iOS 16.2, *)
  private func handleLiveActivityPush(_ userInfo: [AnyHashable: Any]) {
    // FCM data-dict fields are at the TOP level of userInfo (not
    // nested under "data"). This is standard FCM iOS behavior.
    guard let notifType = userInfo["notification_type"] as? String else { return }
    let sessionId = userInfo["session_id"] as? String ?? ""

    switch notifType {
    case "report_ready":
      if !sessionId.isEmpty {
        LiveActivityManager.shared.showReportReadyFromPush(sessionId: sessionId)
      }

    case "status_uploaded":
      LiveActivityManager.shared.updateFromPush(status: "uploading")

    case "status_transcribing", "status_analyzing":
      LiveActivityManager.shared.updateFromPush(status: "analyzing")

    default:
      break // Not a Live Activity-relevant notification
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Register our hand-written AudioConverter plugin alongside the
    // generated registrants. The MethodChannel bridges to
    // lib/services/audio_converter_service.dart::convertM4aToFlac;
    // the EventChannel feeds progress 0.0-1.0 back to the upload UI.
    // See ios/Runner/AudioConverter.swift for the implementation.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioConverter") {
      AudioConverter.register(with: registrar.messenger())
    }
    // Audio-session reactivation channel for post-interruption resume
    // (docs/28 WS3). See ios/Runner/AudioSessionHelper.swift.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AudioSessionHelper") {
      AudioSessionHelper.register(with: registrar.messenger())
    }
    // Live Activity channel — bridges Flutter recording state to the
    // iOS Dynamic Island / Lock Screen via ActivityKit.
    // See ios/Runner/LiveActivityManager.swift.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityManager") {
      let channel = FlutterMethodChannel(
        name: "ai.superwizor/live_activity",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if #available(iOS 16.2, *) {
          LiveActivityManager.shared.handle(call, result: result)
        } else {
          LiveActivityManagerFallback.shared.handle(call, result: result)
        }
      }
    }
  }
}
