import SwiftUI
import AppKit
import WidgetKit
import UserNotifications
import ServiceManagement
import Sparkle

@main
struct HubWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // The menu-bar icon and its panel are AppKit (AppDelegate): a MenuBarExtra cannot be opened from code,
    // and the widget's "+ Lead" has to open the panel at the lead form.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

enum PanelMode { case home, newLead }

/// Lives in the menu bar: shows platform notifications as native macOS banners, opens links the
/// widget hands it, keeps itself up to date, and hosts the setup window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var unread = 0 { didSet { updateIcon() } }
    @Published var panelMode = PanelMode.home
    @Published var recent: [PlatformNotification] = []
    @Published var lastError: String?

    let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var timer: Timer?
    static let pollInterval: TimeInterval = 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        setUpStatusItem()
        if HubStore.rememberedKey == nil { showSetup() }
        startPolling()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "hubwidget", url.host == "new-lead" { showQuickLead() } else { DeepLink.open(url) }
        }
    }

    // MARK: Menu-bar panel

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        statusItem = item
        updateIcon()
        popover.behavior = .transient
        popover.animates = true
        let host = NSHostingController(rootView: PanelView(delegate: self))
        // The panel follows its content: home is short, the lead form is tall.
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
    }

    /// The MH mark (a template image, so macOS tints it for light and dark menu bars) plus the unread count.
    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let mark = NSImage(named: "MenuBarIcon")
        mark?.isTemplate = true
        mark?.accessibilityDescription = "Hub"
        button.image = mark
        button.imagePosition = .imageLeading
        button.title = unread > 0 ? " \(unread)" : ""
    }

    @objc private func togglePanel() {
        if popover.isShown { closePanel() } else { openPanel(.home) }
    }

    func openPanel(_ mode: PanelMode) {
        panelMode = mode
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        popover.contentViewController?.view.window?.makeKey()
    }

    func closePanel() {
        popover.performClose(nil)
        panelMode = .home
    }

    /// The widget's "+ Lead": the panel drops down from the menu bar at the lead form.
    func showQuickLead() { openPanel(.newLead) }

    /// A local confirmation banner; clicking it opens `path` on the platform.
    func confirm(title: String, body: String, path: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.userInfo = ["path": path]
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
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

/// What drops down from the Hub icon: recent notifications and actions, or the new-lead form.
struct PanelView: View {
    @ObservedObject var delegate: AppDelegate

    var body: some View {
        Group {
            switch delegate.panelMode {
            case .home: home
            case .newLead: QuickLeadView(delegate: delegate) { delegate.closePanel() }.frame(height: 560)
            }
        }
        .frame(width: 340)
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Hub").font(.headline)
                Spacer()
                Button { delegate.openPanel(.newLead) } label: { Label("New lead", systemImage: "plus") }
                    .keyboardShortcut("l")
            }
            .padding(12)
            Divider()
            if delegate.recent.isEmpty {
                Text("No new notifications").font(.callout).foregroundStyle(.secondary).padding(12)
            } else {
                ForEach(delegate.recent) { n in
                    Button {
                        if let url = DeepLink.webURL(n.actionUrl) { NSWorkspace.shared.open(url) }
                        delegate.closePanel()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(n.title ?? "Notification").font(.callout.weight(.medium)).lineLimit(1)
                            if let body = n.body { Text(body).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Button("Clear") { delegate.recent = []; delegate.unread = 0 }
                    .buttonStyle(.link).padding(.horizontal, 12).padding(.bottom, 6)
            }
            if let error = delegate.lastError {
                Text(error).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.bottom, 6)
            }
            Divider()
            HStack(spacing: 14) {
                Button("Open platform") { NSWorkspace.shared.open(URL(string: HubStore.appBase)!); delegate.closePanel() }
                Button("Settings…") { delegate.closePanel(); delegate.showSetup() }
                Button("Updates…") { delegate.closePanel(); delegate.updater.checkForUpdates(nil) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .buttonStyle(.link)
            .font(.caption)
            .padding(12)
        }
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
