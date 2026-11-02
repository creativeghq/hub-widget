import SwiftUI
import WidgetKit
import AppKit

@main
struct HubWidgetApp: App {
    var body: some Scene {
        WindowGroup("Hub Widget") {
            SettingsView()
                .frame(minWidth: 560, minHeight: 620)
                .onOpenURL(perform: DeepLink.open)
        }
        .windowResizability(.contentSize)
        .handlesExternalEvents(matching: ["*"])
    }
}

/// Widget taps arrive as `hubwidget://open?path=/finance?tab=ar` and go on to the web app.
enum DeepLink {
    static func open(_ url: URL) {
        guard url.scheme == "hubwidget" else { return }
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "path" }?.value
        if let target = HubStore.appURL(path) {
            NSWorkspace.shared.open(target)
        }
    }
}
