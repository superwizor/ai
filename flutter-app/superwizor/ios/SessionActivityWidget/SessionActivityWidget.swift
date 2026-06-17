// SessionActivityWidget — SwiftUI Live Activity presentation for the
// iOS Lock Screen, Dynamic Island (compact + expanded), and the
// "ended" state.
//
// Design language:
//   • Dark teal background (#0A2326) matching the Euphire theme
//   • Ember accent (#E8734A) for recording dot and active accents
//   • Montserrat for labels, Merriweather for patient alias
//   • Compact layout for Dynamic Island, expanded for Lock Screen

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct SessionActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            // ───────────────────────────────────────────────────────
            // LOCK SCREEN presentation (the large banner)
            // ───────────────────────────────────────────────────────
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded regions ──────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        // Pulsing recording dot
                        if context.state.reportSessionId == nil && !context.state.isPaused {
                            Circle()
                                .fill(Color(red: 0.91, green: 0.45, blue: 0.29)) // Ember
                                .frame(width: 8, height: 8)
                        }
                        Text(context.attributes.patientAlias)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.reportSessionId == nil {
                        // Timer
                        Text(timerString(context.state.elapsedSeconds))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))

                    if let sessionId = context.state.reportSessionId {
                        Link(destination: URL(string: "superwizor://report/\(sessionId)")!) {
                            Text("Pokaż raport")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.91, green: 0.45, blue: 0.29))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }
                }

                DynamicIslandExpandedRegion(.center) {}
            } compactLeading: {
                // ── Compact leading (pill left) ──────────────────
                HStack(spacing: 4) {
                    if context.state.reportSessionId == nil && !context.state.isPaused {
                        Circle()
                            .fill(Color(red: 0.91, green: 0.45, blue: 0.29))
                            .frame(width: 6, height: 6)
                    } else if context.state.reportSessionId != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                }
            } compactTrailing: {
                // ── Compact trailing (pill right) ────────────────
                if context.state.reportSessionId == nil {
                    Text(timerString(context.state.elapsedSeconds))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            } minimal: {
                // ── Minimal (when another app has the island) ────
                if context.state.reportSessionId != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                } else {
                    Circle()
                        .fill(context.state.isPaused
                              ? Color.white.opacity(0.4)
                              : Color(red: 0.91, green: 0.45, blue: 0.29))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOSApplicationExtension 16.1, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            // Left: recording indicator
            VStack {
                if context.state.reportSessionId != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                } else if context.state.isPaused {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.white.opacity(0.5))
                } else {
                    Circle()
                        .fill(Color(red: 0.91, green: 0.45, blue: 0.29))
                        .frame(width: 12, height: 12)
                }
            }
            .frame(width: 32)

            // Center: patient alias + status
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.patientAlias)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(context.state.statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Right: timer or report button
            if let sessionId = context.state.reportSessionId {
                Link(destination: URL(string: "superwizor://report/\(sessionId)")!) {
                    Text("Pokaż")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.91, green: 0.45, blue: 0.29))
                        .clipShape(Capsule())
                }
            } else {
                Text(timerString(context.state.elapsedSeconds))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.04, green: 0.14, blue: 0.15)) // #0A2326
    }
}

// MARK: - Helpers

private func timerString(_ totalSeconds: Int) -> String {
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
}
