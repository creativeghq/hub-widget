import Foundation

/// Addresses, the remembered key and the last good pulse.
/// An ad-hoc signed build has no App Group, so each target has its own defaults; the app's key reaches
/// the widget through `appKeyFile`, a path both sandboxes are granted by a temporary exception.
enum HubStore {
    static let apiBase = "https://bgbavxtjlbvgplozizxu.supabase.co/functions/v1"
    static let appBase = "https://app.materialshub.gr"

    static var defaults: UserDefaults { .standard }

    /// The last key that worked in this process, so a second widget needs no key of its own.
    static var rememberedKey: String? {
        get { nonEmpty(defaults.string(forKey: "rememberedKey")) }
        set { defaults.set(newValue, forKey: "rememberedKey") }
    }

    /// The key saved in the app's Settings: what every widget uses unless its own key is accepted.
    static var appKey: String? {
        nonEmpty(try? String(contentsOf: appKeyFile, encoding: .utf8))
    }

    static func publishAppKey(_ key: String?) {
        let fm = FileManager.default
        guard let key else { try? fm.removeItem(at: appKeyFile); return }
        try? fm.createDirectory(at: appKeyFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        fm.createFile(atPath: appKeyFile.path, contents: Data(key.utf8), attributes: [.posixPermissions: 0o600])
    }

    /// In the real home, not the sandbox container — must match the home-relative paths in project.yml.
    static var appKeyFile: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingUTF8: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/HubWidget/key")
    }

    static func cachedPulse(key: String, workspaceId: String?) -> Pulse? {
        guard let data = defaults.data(forKey: cacheKey(key, workspaceId)) else { return nil }
        return try? JSONDecoder.pulse.decode(Pulse.self, from: data)
    }

    /// The cached pulse if it was fetched within `maxAge` — so a click inside the widget is instant.
    static func freshPulse(key: String, workspaceId: String?, maxAge: TimeInterval) -> Pulse? {
        let at = defaults.double(forKey: cacheKey(key, workspaceId) + ".at")
        guard at > 0, at > defaults.double(forKey: "pulse.expiredAt"),
              Date().timeIntervalSince1970 - at < maxAge else { return nil }
        return cachedPulse(key: key, workspaceId: workspaceId)
    }

    static func storeCache(_ pulse: Pulse, key: String, workspaceId: String?) {
        defaults.set(try? JSONEncoder.pulse.encode(pulse), forKey: cacheKey(key, workspaceId))
        defaults.set(Date().timeIntervalSince1970, forKey: cacheKey(key, workspaceId) + ".at")
    }

    /// After an action changed the data, the next render must fetch rather than serve the click cache.
    static func expireFreshPulses() {
        defaults.set(Date().timeIntervalSince1970, forKey: "pulse.expiredAt")
    }

    /// Opens the menu-bar app's quick-add form.
    static let newLeadLink = URL(string: "hubwidget://new-lead")!

    /// Where the notification feed got to; nil = start from now.
    static var notificationCursor: String? {
        get { nonEmpty(defaults.string(forKey: "notificationCursor")) }
        set { defaults.set(newValue, forKey: "notificationCursor") }
    }

    static var notificationsEnabled: Bool {
        get { defaults.object(forKey: "notificationsEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "notificationsEnabled") }
    }

    /// A deep link into the web app. `path` is the section/metric `url` the server sent.
    static func appURL(_ path: String?) -> URL? {
        let p = path ?? "/"
        return URL(string: appBase + (p.hasPrefix("/") ? p : "/" + p))
    }

    /// The widget hands the path to the app, which opens it in the browser.
    static func widgetLink(_ path: String?) -> URL {
        var c = URLComponents()
        c.scheme = "hubwidget"
        c.host = "open"
        c.queryItems = [URLQueryItem(name: "path", value: path ?? "/")]
        return c.url ?? URL(string: "hubwidget://open")!
    }

    static func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    private static func cacheKey(_ key: String, _ workspaceId: String?) -> String {
        "pulse.\(key.suffix(8)).\(workspaceId ?? "default")"
    }
}

extension JSONEncoder {
    static let pulse: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
