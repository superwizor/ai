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
            let isPaused = status == "paused" || status == "interrupted"
            let statusText = localizedStatus(status)
            let phase = processingPhase(status)
            let sessionId = args["sessionId"] as? String
            update(statusText: statusText, isPaused: isPaused, elapsedSeconds: elapsed, processingPhase: phase, sessionId: sessionId)
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

        case "isReportReady":
            // Returns true if the current Live Activity is showing
            // a completed report (reportSessionId is set AND processingPhase is nil). Used by
            // the Dart-side resume observer to decide whether to
            // dismiss the widget on app resume.
            if let activity = currentActivity {
                result(activity.content.state.reportSessionId != nil && activity.content.state.processingPhase == nil)
            } else {
                result(false) // No active LA → nothing to dismiss
            }

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
            readyReportCount: nil,
            recordingStartDate: Date().addingTimeInterval(TimeInterval(-elapsedSeconds))
        )

        do {
            // 15-minute stale date: if the app is killed before the first
            // update arrives, iOS dims the widget rather than showing a
            // false "recording" status forever.
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
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

    private func update(statusText: String, isPaused: Bool, elapsedSeconds: Int, processingPhase: String?, sessionId: String? = nil) {
        guard let activity = currentActivity else { return }
        
        let recordingStartDate: Date?
        if isPaused {
            recordingStartDate = nil
        } else {
            recordingStartDate = Date().addingTimeInterval(TimeInterval(-elapsedSeconds))
        }
        
        let state = LiveActivityAttributes.ContentState(
            statusText: statusText,
            isPaused: isPaused,
            elapsedSeconds: elapsedSeconds,
            reportSessionId: sessionId ?? activity.content.state.reportSessionId,
            processingPhase: processingPhase,
            readyReportCount: nil,
            recordingStartDate: recordingStartDate
        )
        Task {
            // 15-minute stale date: safety net so the widget dims if
            // the app goes away mid-pipeline instead of showing a
            // permanently false status like "Pracujemy nad raportem".
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
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
            readyReportCount: reportCount > 1 ? reportCount : nil,
            recordingStartDate: nil
        )
        Task {
            // Report-ready can linger longer — 4 hours before iOS dims it.
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(4 * 3600))
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

    // MARK: - Push-driven updates (called from AppDelegate)
    //
    // These are called from application(_:didReceiveRemoteNotification:)
    // on the NATIVE side, bypassing the Dart MethodChannel entirely.
    // This is critical because background Dart isolates run on a
    // separate FlutterEngine where our MethodChannel is NOT registered.

    /// Update the Live Activity with an intermediate pipeline status.
    /// Called when a silent data-only FCM push arrives for status_uploaded,
    /// status_transcribing, or status_analyzing.
    func updateFromPush(status: String) {
        guard currentActivity != nil else {
            debugPrint("[LiveActivity] updateFromPush: no active activity, ignoring")
            return
        }
        let statusText = localizedStatus(status)
        let phase = processingPhase(status)
        update(statusText: statusText, isPaused: false, elapsedSeconds: 0, processingPhase: phase)
        debugPrint("[LiveActivity] updateFromPush: \(status)")
    }

    /// Transition to "report ready" state. Called when a report_ready
    /// FCM push arrives (visible push, not silent).
    func showReportReadyFromPush(sessionId: String) {
        guard currentActivity != nil else {
            debugPrint("[LiveActivity] showReportReadyFromPush: no active activity, ignoring")
            return
        }
        showReportReady(sessionId: sessionId, reportCount: 1)
        debugPrint("[LiveActivity] showReportReadyFromPush: \(sessionId)")
    }

    /// Dismiss any Live Activities that survived a previous app session.
    /// Called once during didFinishLaunchingWithOptions (cold start).
    /// Safe because: if the user is opening the app, the in-app UI
    /// takes over and the widget is redundant.
    func cleanupOrphaned() {
        let activities = Activity<LiveActivityAttributes>.activities
        guard !activities.isEmpty else { return }
        debugPrint("[LiveActivity] cleanupOrphaned: ending \(activities.count) orphaned activities")
        for activity in activities {
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
        case "interrupted": return "Wstrzymane (połączenie)"
        case "uploading": return "AI opracowuje wnioski z sesji…"
        case "analyzing": return "AI opracowuje wnioski z sesji…"
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
