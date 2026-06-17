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

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// The currently active Live Activity, if any.
    private var currentActivity: Activity<LiveActivityAttributes>?

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
            update(statusText: statusText, isPaused: isPaused, elapsedSeconds: elapsed)
            result(true)

        case "reportReady":
            guard let args = call.arguments as? [String: Any],
                  let sessionId = args["sessionId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "Missing sessionId",
                                    details: nil))
                return
            }
            showReportReady(sessionId: sessionId)
            result(true)

        case "stop":
            stop()
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - ActivityKit operations

    private func start(patientAlias: String, elapsedSeconds: Int) {
        // End any previous activity first.
        if let existing = currentActivity {
            Task {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }

        let attributes = LiveActivityAttributes(patientAlias: patientAlias)
        let state = LiveActivityAttributes.ContentState(
            statusText: localizedStatus("recording"),
            isPaused: false,
            elapsedSeconds: elapsedSeconds,
            reportSessionId: nil
        )

        do {
            let content = ActivityContent(state: state, staleDate: nil)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil  // No push updates; we update locally.
            )
            currentActivity = activity
            debugPrint("[LiveActivity] started id=\(activity.id)")
        } catch {
            debugPrint("[LiveActivity] start failed: \(error)")
        }
    }

    private func update(statusText: String, isPaused: Bool, elapsedSeconds: Int) {
        guard let activity = currentActivity else { return }
        let state = LiveActivityAttributes.ContentState(
            statusText: statusText,
            isPaused: isPaused,
            elapsedSeconds: elapsedSeconds,
            reportSessionId: nil
        )
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    private func showReportReady(sessionId: String) {
        guard let activity = currentActivity else { return }
        let state = LiveActivityAttributes.ContentState(
            statusText: NSLocalizedString("Nowy raport czeka w kartotece", comment: ""),
            isPaused: false,
            elapsedSeconds: 0,
            reportSessionId: sessionId
        )
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
        }
    }

    private func stop() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    // MARK: - Localisation helpers

    /// Maps the Flutter-side status enum name to a Polish status string
    /// for the Live Activity presentation. These are hard-coded here
    /// because the widget extension cannot access Flutter's ARB system.
    private func localizedStatus(_ status: String) -> String {
        switch status {
        case "recording": return "Sesja w toku"
        case "paused":    return "Pauza"
        case "uploading": return "Wgrywanie nagrania..."
        case "analyzing": return "Analizowanie sesji..."
        case "reportReady": return "Nowy raport czeka w kartotece"
        default: return status
        }
    }
}

// MARK: - Fallback for iOS < 16.1

/// Stub used on iOS versions that don't support Live Activities.
class LiveActivityManagerFallback {
    static let shared = LiveActivityManagerFallback()

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Silently succeed — the Flutter side handles the feature being
        // unavailable gracefully.
        result(true)
    }
}
