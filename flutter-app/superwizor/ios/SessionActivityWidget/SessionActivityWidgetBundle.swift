// SessionActivityWidgetBundle — entry point for the Widget Extension.
// The extension process runs separately from Runner; it renders the
// Live Activity's Lock Screen, Dynamic Island, and "ended" views.
//
// The LiveActivityAttributes struct is shared between the main app
// (Runner target) and this extension target — both compile the same
// LiveActivityAttributes.swift file.

import SwiftUI
import WidgetKit

@main
struct SessionActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOSApplicationExtension 16.1, *) {
            SessionActivityWidget()
        }
    }
}
