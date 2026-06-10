import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
  }
}
