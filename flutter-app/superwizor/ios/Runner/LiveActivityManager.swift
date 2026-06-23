// LiveActivityManager — handles ActivityKit lifecycle from
// Flutter MethodChannel calls.
//
// This runs inside the MAIN app target (Runner), not a widget
// extension. iOS 16.1+ Live Activities are started/updated/ended
// from the main app; the system renders the Dynamic Island and
// Lock Screen presentations from the Activity's content state.
//
// Unlike a WidgetKit extension (which renders via a separate
// process), Live Activities share the main app's process, so
// we can manage them directly from the AppDelegate/MethodChannel
// handler without an App Group or shared container.

import ActivityKit
import Flutter
import Foundation

@available(iOS 16.2, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// The currently active Live Activity, if any.
    private var currentActivity: Activity<LiveActivityAttributes>? {
        return Activity<LiveActivityAttributes>.activities.first
    }

    // MARK: - MethodChannel handler

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let alias = args["patientAlias"] as? String,
                  let elapsed = args["elapsedSeconds"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing patientAlias or elapsedSeconds",
                                    details: nil))
                return
            }
            start(patientAlias: alias, elapsedSeconds: elapsed)
            result(true)

        case "update":
            guard let args = call.arguments as? [String: Any],
                  let status = args["status"] as? String,
                  let elapsed = args["elapsedSeconds"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing status or elapsedSeconds",
                                    details: nil))
                return
            }
            let isPaused = status == "paused"
            let statusText = localizedStatus(status)
            let phase = processingPhase(status)
            update(statusText: statusText, isPaused: isPaused, elapsedSeconds: elapsed, processingPhase: phase)
            result(true)

        case "reportReady":
            guard let args = call.arguments as? [String: Any],
                  let sessionId = args["sessionId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing sessionId",
                                    details: nil))
                return
            }
            let count = args["reportCount"] as? Int ?? 1
            showReportReady(sessionId: sessionId, reportCount: count)
            result(true)

        case "stop":
            stop()
            result(true)

        case "checkPermission":
            let info = ActivityAuthorizationInfo()
            result(info.areActivitiesEnabled)

        case "openSettings":
            if let url = URL(string: UIApplication.openSettingsURLString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - ActivityKit operations

    private func start(patientAlias: String, elapsedSeconds: Int) {
        // End any previous activities first.
        for activity in Activity<LiveActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        let attributes = LiveActivityAttributes(patientAlias: patientAlias)
        let state = LiveActivityAttributes.ContentState(
            statusText: localizedStatus("recording"),
            isPaused: false,
            elapsedSeconds: elapsedSeconds,
            reportSessionId: nil,
            processingPhase: nil,
            readyReportCount: nil
        )

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil  // No push updates; we update locally.
            )
            debugPrint("[LiveActivity] started successfully")
        } catch {
            debugPrint("[LiveActivity] start failed: \(error)")
        }
    }

    private func update(statusText: String, isPaused: Bool, elapsedSeconds: Int, processingPhase: String?) {
        guard let activity = currentActivity else { return }
        let state = LiveActivityAttributes.ContentState(
            statusText: statusText,
            isPaused: isPaused,
            elapsedSeconds: elapsedSeconds,
            reportSessionId: nil,
            processingPhase: processingPhase,
            readyReportCount: nil
        )
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    private func showReportReady(sessionId: String, reportCount: Int) {
        guard let activity = currentActivity else { return }
        let statusText = reportCount > 1
            ? "Nowe raporty czekają w kartotece"
            : "Nowy raport czeka w kartotece"
        let state = LiveActivityAttributes.ContentState(
            statusText: statusText,
            isPaused: false,
            elapsedSeconds: 0,
            reportSessionId: sessionId,
            processingPhase: nil,
            readyReportCount: reportCount > 1 ? reportCount : nil
        )
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    private func stop() {
        for activity in Activity<LiveActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    // MARK: - Localisation helpers

    /// Maps the Flutter-side status enum name to a Polish status string
    /// for the Live Activity presentation. These are hard-coded here
    /// because the widget extension cannot access Flutter's ARB system.
    private func localizedStatus(_ status: String) -> String {
        switch status {
        case "recording": return "Sesja w toku"
        case "paused":    return "Pauza"
        case "uploading": return "Przesyłamy nagranie…"
        case "analyzing": return "Pracujemy nad raportem"
        case "reportReady": return "Nowy raport czeka w kartotece"
        default: return status
        }
    }

    /// Returns the processing phase identifier for widget styling.
    private func processingPhase(_ status: String) -> String? {
        switch status {
        case "uploading": return "uploading"
        case "analyzing": return "analyzing"
        default: return nil
        }
    }
}

// MARK: - Fallback for iOS < 16.2

/// Stub used on iOS versions that don't support Live Activities.
class LiveActivityManagerFallback {
    static let shared = LiveActivityManagerFallback()

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkPermission":
            // Live Activities not available on this iOS version.
            result(false)
        default:
            // Silently succeed — the Flutter side handles the feature being
            // unavailable gracefully.
            result(true)
        }
    }
}
