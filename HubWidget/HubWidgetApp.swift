import SwiftUI
import AppKit
import WidgetKit
import UserNotifications
import ServiceManagement
import Sparkle

@main
struct HubWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(delegate: delegate)
        } label: {
            Image(systemName: delegate.unread > 0 ? "square.grid.2x2.fill" : "square.grid.2x2")
        }
    }
}

/// Lives in the menu bar: shows platform notifications as native macOS banners, opens links the
/// widget hands it, keeps itself up to date, and hosts the setup window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var unread = 0
    @Published var recent: [PlatformNotification] = []
    @Published var lastError: String?

    let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var window: NSWindow?
    private var timer: Timer?
    static let pollInterval: TimeInterval = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        if HubStore.rememberedKey == nil { showSetup() }
        startPolling()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(DeepLink.open)
    }

    func showSetup() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(delegate: self)))
            w.title = "Hub Widget"
            w.setContentSize(NSSize(width: 580, height: 640))
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: Notifications

    func startPolling() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        Task { await poll() }
    }

    func requestNotificationPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func poll() async {
        guard HubStore.notificationsEnabled, let key = HubStore.rememberedKey else { return }
        do {
            let feed = try await PulseClient(apiKey: key).notifications(since: HubStore.notificationCursor)
            HubStore.notificationCursor = feed.cursor ?? HubStore.notificationCursor
            lastError = nil
            guard !feed.notifications.isEmpty else { return }
            for n in feed.notifications { await post(n) }
            recent = Array((feed.notifications.reversed() + recent).prefix(8))
            unread += feed.notifications.count
            // Something happened on the platform: refresh the widgets now instead of in 15 minutes.
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func post(_ n: PlatformNotification) async {
        let content = UNMutableNotificationContent()
        content.title = n.title ?? "Hub"
        if let body = n.body { content.body = body }
        content.sound = .default
        content.threadIdentifier = n.type ?? "hub"
        if let url = n.actionUrl { content.userInfo = ["path": url] }
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: n.id, content: content, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let path = response.notification.request.content.userInfo["path"] as? String
        await MainActor.run {
            unread = max(0, unread - 1)
            if let url = DeepLink.webURL(path) { NSWorkspace.shared.open(url) }
        }
    }

    // MARK: Login item

    var opensAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                lastError = "Could not change Open at login: \(error.localizedDescription)"
            }
            objectWillChange.send()
        }
    }
}

struct MenuContent: View {
    @ObservedObject var delegate: AppDelegate

    var body: some View {
        if delegate.recent.isEmpty {
            Text("No new notifications")
        } else {
            ForEach(delegate.recent) { n in
                Button(n.title ?? "Notification") {
                    if let url = DeepLink.webURL(n.actionUrl) { NSWorkspace.shared.open(url) }
                }
            }
            Button("Clear") { delegate.recent = []; delegate.unread = 0 }
        }
        if let error = delegate.lastError { Text(error).font(.caption) }
        Divider()
        Button("Open platform") { NSWorkspace.shared.open(URL(string: HubStore.appBase)!) }
        Button("Settings…") { delegate.showSetup() }
        Button("Check for updates…") { delegate.updater.checkForUpdates(nil) }
        Divider()
        Button("Quit Hub Widget") { NSApp.terminate(nil) }
    }
}

/// Widget taps arrive as `hubwidget://open?path=/finance?tab=ar` and go on to the web app.
enum DeepLink {
    static func open(_ url: URL) {
        guard url.scheme == "hubwidget" else { return }
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "path" }?.value
        if let target = webURL(path) { NSWorkspace.shared.open(target) }
    }

    /// A platform path (`/quotes/manage/…`) or an absolute https URL.
    static func webURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return URL(string: HubStore.appBase) }
        if path.hasPrefix("https://") { return URL(string: path) }
        return HubStore.appURL(path)
    }
}
