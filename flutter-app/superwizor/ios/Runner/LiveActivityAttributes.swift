// LiveActivityAttributes — defines the data contract between
// the main Flutter app and the Live Activity widget on iOS.
//
// Static attributes are set once when the activity starts (patient
// alias). Dynamic content state is updated as the recording
// progresses (status text, elapsed time, pause state, report ID).

import ActivityKit
import Foundation

struct LiveActivityAttributes: ActivityAttributes {
    /// Patient pseudonym (set once at activity start).
    var patientAlias: String

    struct ContentState: Codable, Hashable {
        /// Localised status string (e.g. "Sesja w toku", "Pauza").
        var statusText: String
        /// Whether the recording is paused.
        var isPaused: Bool
        /// Seconds since the recording started.
        var elapsedSeconds: Int
        /// Non-nil when the backend report is ready — the widget
        /// shows a "Show report" deep link targeting this session.
        var reportSessionId: String?
        /// Processing phase: "uploading", "analyzing", or nil.
        /// Used by the widget to show appropriate spinner color.
        var processingPhase: String?
        /// When > 1, widget shows "Nowe raporty czekają" with count
        /// instead of a single patient name.
        var readyReportCount: Int?
    }
}
