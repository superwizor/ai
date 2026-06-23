// SessionActivityWidget — SwiftUI Live Activity presentation for the
// iOS Lock Screen, Dynamic Island (compact + expanded), and the
// "ended" state.
//
// Design language:
//   • Dark teal background (#0A2326) with subtle gradient
//   • Ember accent (#E8734A) for recording dot
//   • Gold (#FCAE2F) for pause, report button, radiating rings
//   • Blue (#5BA4CF) for uploading, Purple (#9B72CF) for analyzing
//   • Green (#4ADE80) for report-ready checkmark
//   • Recording state shows radiating gold rings from a small ember dot

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Theme

private enum WidgetTheme {
    static let darkTeal = Color(red: 0.04, green: 0.14, blue: 0.15) // #0A2326
    static let ember = Color(red: 0.91, green: 0.45, blue: 0.29)     // #E8734A
    static let gold = Color(red: 0.99, green: 0.68, blue: 0.18)      // #FCAE2F
    static let processingBlue = Color(red: 0.36, green: 0.64, blue: 0.81) // #5BA4CF
    static let processingPurple = Color(red: 0.61, green: 0.45, blue: 0.81) // #9B72CF
    static let successGreen = Color(red: 0.29, green: 0.87, blue: 0.50) // #4ADE80
}

@available(iOSApplicationExtension 16.2, *)
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
                        if isRecording(context) {
                            // Small ember dot
                            Circle()
                                .fill(WidgetTheme.ember)
                                .frame(width: 6, height: 6)
                        } else if isProcessing(context) {
                            ProgressView()
                                .tint(processingColor(context))
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        }
                        Text(displayAlias(context))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if !hasReport(context) && !isProcessing(context) {
                        if context.state.isPaused {
                            Text(timerString(context.state.elapsedSeconds))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        } else {
                            Text(Date(timeIntervalSinceNow: -Double(context.state.elapsedSeconds)), style: .timer)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                    if isProcessing(context) {
                        Text(context.state.processingPhase == "uploading" ? "Przesyłanie" : "Analiza")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(processingColor(context))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(processingColor(context).opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.6))

                    if let sessionId = context.state.reportSessionId {
                        let buttonLabel = hasMultipleReports(context) ? "Otwórz kartotekę" : "Pokaż raport"
                        Link(destination: URL(string: "superwizor://report/\(sessionId)")!) {
                            Text(buttonLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(WidgetTheme.gold)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 4)
                    }

                    if context.state.isPaused {
                        Image(systemName: "pause.circle")
                            .font(.system(size: 18))
                            .foregroundColor(WidgetTheme.gold.opacity(0.6))
                            .padding(.top, 4)
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    // Spacer to push content to leading/trailing
                }
            } compactLeading: {
                // ── Compact leading (pill left) ──────────────────
                Group {
                    if hasReport(context) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(WidgetTheme.successGreen)
                    } else if context.state.isPaused {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(WidgetTheme.gold)
                                .frame(width: 7, height: 7)
                            Text("Pauza")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(WidgetTheme.gold)
                                .minimumScaleFactor(0.7)
                        }
                    } else if isProcessing(context) {
                        ProgressView()
                            .tint(processingColor(context))
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                    } else {
                        // Recording — prominent label with pulsing dot.
                        HStack(spacing: 4) {
                            Circle()
                                .fill(WidgetTheme.ember)
                                .frame(width: 7, height: 7)
                            Text("Sesja")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } compactTrailing: {
                // ── Compact trailing (pill right) ────────────────
                Group {
                    if hasReport(context) {
                        if hasMultipleReports(context) {
                            Text("\(context.state.readyReportCount ?? 2)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(WidgetTheme.gold)
                                .clipShape(Capsule())
                        } else {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 12))
                                .foregroundColor(WidgetTheme.successGreen)
                        }
                    } else if isProcessing(context) {
                        Text(context.state.processingPhase == "uploading" ? "↑" : "✦")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(processingColor(context))
                    } else {
                        if context.state.isPaused {
                            Text(timerString(context.state.elapsedSeconds))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        } else {
                            Text(Date(timeIntervalSinceNow: -Double(context.state.elapsedSeconds)), style: .timer)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } minimal: {
                // ── Minimal (when another app has the island) ────
                if hasReport(context) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(WidgetTheme.successGreen)
                } else if isProcessing(context) {
                    ProgressView()
                        .tint(processingColor(context))
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                } else {
                    Circle()
                        .fill(context.state.isPaused
                              ? WidgetTheme.gold
                              : WidgetTheme.ember)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOSApplicationExtension 16.2, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivityAttributes>

    private var isReport: Bool {
        context.state.reportSessionId != nil
    }

    private var isPaused: Bool {
        context.state.isPaused
    }

    private var isProcessingState: Bool {
        context.state.processingPhase != nil
    }

    private var isRecordingState: Bool {
        !isReport && !isPaused && !isProcessingState
    }

    private var multiReport: Bool {
        (context.state.readyReportCount ?? 0) > 1
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: status indicator
            lockScreenIndicator()
                .frame(width: 48, height: 48)

            // Center: patient alias + status
            VStack(alignment: .leading, spacing: 3) {
                Text(displayAlias(context))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(context.state.statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.55))
                    .lineLimit(2)
            }

            Spacer()

            // Right: timer, spinner, or report button
            lockScreenTrailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .padding(3) // Inset for visible border within iOS clip region
        .background(
            ZStack {
                // Fill background
                LinearGradient(
                    gradient: Gradient(colors: [
                        WidgetTheme.darkTeal.opacity(0.95),
                        Color(red: 0.06, green: 0.20, blue: 0.22).opacity(0.9)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Inner border — dark forest green, fully visible
                // because it's drawn inside the system-clipped region
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        Color(red: 0.08, green: 0.35, blue: 0.25).opacity(0.8),
                        lineWidth: 2
                    )
                    .padding(1)
            }
        )
    }

    // MARK: - Lock Screen indicator (left icon area)

    @ViewBuilder
    private func lockScreenIndicator() -> some View {
        if isReport {
            // Report ready — green checkmark + optional count badge
            ZStack {
                Circle()
                    .fill(WidgetTheme.successGreen.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(WidgetTheme.successGreen)
                if multiReport {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(context.state.readyReportCount ?? 2)")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                                .frame(width: 16, height: 16)
                                .background(WidgetTheme.gold)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(WidgetTheme.darkTeal, lineWidth: 1.5)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 48, height: 48)
                }
            }
        } else if isPaused {
            // Paused — gold pause icon
            ZStack {
                Circle()
                    .fill(WidgetTheme.gold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(WidgetTheme.gold)
            }
        } else if isProcessingState {
            // Uploading/Analyzing — spinner
            let color = context.state.processingPhase == "uploading"
                ? WidgetTheme.processingBlue
                : WidgetTheme.processingPurple
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 2.5)
                    .frame(width: 32, height: 32)
                ProgressView()
                    .tint(color)
                    .scaleEffect(0.9)
            }
        } else {
            // Recording — animated radiating rings from ember dot.
            // TimelineView(.animation) renders at display refresh rate
            // when the screen is awake; pauses automatically when the
            // display sleeps (zero battery impact).
            if #available(iOSApplicationExtension 17.0, *) {
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = t.truncatingRemainder(dividingBy: 2.0) / 2.0
                    let pulse = sin(phase * .pi * 2)
                    let innerScale = 0.90 + 0.10 * pulse
                    let outerScale = 0.85 + 0.15 * pulse
                    let ringOpacity = 0.12 + 0.13 * pulse

                    ZStack {
                        Circle()
                            .stroke(WidgetTheme.gold.opacity(ringOpacity + 0.05), lineWidth: 1)
                            .frame(width: 36, height: 36)
                            .scaleEffect(innerScale)
                        Circle()
                            .stroke(WidgetTheme.gold.opacity(ringOpacity), lineWidth: 1)
                            .frame(width: 44, height: 44)
                            .scaleEffect(outerScale)
                        Circle()
                            .fill(WidgetTheme.ember)
                            .frame(width: 8, height: 8)
                            .shadow(color: WidgetTheme.ember.opacity(0.6), radius: 5)
                    }
                }
            } else {
                // iOS 16.x fallback — static rings
                ZStack {
                    Circle()
                        .stroke(WidgetTheme.gold.opacity(0.2), lineWidth: 1)
                        .frame(width: 36, height: 36)
                    Circle()
                        .stroke(WidgetTheme.gold.opacity(0.12), lineWidth: 1)
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(WidgetTheme.ember)
                        .frame(width: 8, height: 8)
                        .shadow(color: WidgetTheme.ember.opacity(0.6), radius: 5)
                }
            }
        }
    }

    // MARK: - Lock Screen trailing (right side)

    @ViewBuilder
    private func lockScreenTrailing() -> some View {
        if isReport {
            if let sessionId = context.state.reportSessionId {
                let label = multiReport ? "Otwórz" : "Pokaż"
                Link(destination: URL(string: "superwizor://report/\(sessionId)")!) {
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(WidgetTheme.gold)
                        .clipShape(Capsule())
                }
            }
        } else if isProcessingState {
            ProgressView()
                .tint(context.state.processingPhase == "uploading"
                      ? WidgetTheme.processingBlue
                      : WidgetTheme.processingPurple)
                .scaleEffect(0.8)
                .frame(width: 22, height: 22)
        } else {
            if context.state.isPaused {
                Text(timerString(context.state.elapsedSeconds))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Text(Date(timeIntervalSinceNow: -Double(context.state.elapsedSeconds)), style: .timer)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Free-function Helpers

@available(iOSApplicationExtension 16.2, *)
private func isRecording(_ context: ActivityViewContext<LiveActivityAttributes>) -> Bool {
    context.state.reportSessionId == nil
        && !context.state.isPaused
        && context.state.processingPhase == nil
}

@available(iOSApplicationExtension 16.2, *)
private func isProcessing(_ context: ActivityViewContext<LiveActivityAttributes>) -> Bool {
    context.state.processingPhase != nil
}

@available(iOSApplicationExtension 16.2, *)
private func hasReport(_ context: ActivityViewContext<LiveActivityAttributes>) -> Bool {
    context.state.reportSessionId != nil
}

@available(iOSApplicationExtension 16.2, *)
private func hasMultipleReports(_ context: ActivityViewContext<LiveActivityAttributes>) -> Bool {
    (context.state.readyReportCount ?? 0) > 1
}

@available(iOSApplicationExtension 16.2, *)
private func processingColor(_ context: ActivityViewContext<LiveActivityAttributes>) -> Color {
    context.state.processingPhase == "uploading"
        ? WidgetTheme.processingBlue
        : WidgetTheme.processingPurple
}

@available(iOSApplicationExtension 16.2, *)
private func displayAlias(_ context: ActivityViewContext<LiveActivityAttributes>) -> String {
    if hasMultipleReports(context) {
        return "Twoje raporty"
    }
    return context.attributes.patientAlias
}

private func timerString(_ totalSeconds: Int) -> String {
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
}
