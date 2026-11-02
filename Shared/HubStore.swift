import Foundation

/// Addresses, the remembered key and the last good pulse.
/// An ad-hoc signed build has no App Group, so the app and the widget extension each keep their own
/// copy in their own sandbox: the widget's key comes from its "Edit Widget" panel, not from the app.
enum HubStore {
    static let apiBase = "https://bgbavxtjlbvgplozizxu.supabase.co/functions/v1"
    static let appBase = "https://app.materialshub.gr"

    static var defaults: UserDefaults { .standard }

    /// The last key that worked in this process, so a second widget needs no key of its own.
    static var rememberedKey: String? {
        get { nonEmpty(defaults.string(forKey: "rememberedKey")) }
        set { defaults.set(newValue, forKey: "rememberedKey") }
    }

    static func cachedPulse(key: String, workspaceId: String?) -> Pulse? {
        guard let data = defaults.data(forKey: cacheKey(key, workspaceId)) else { return nil }
        return try? JSONDecoder.pulse.decode(Pulse.self, from: data)
    }

    static func storeCache(_ pulse: Pulse, key: String, workspaceId: String?) {
        defaults.set(try? JSONEncoder.pulse.encode(pulse), forKey: cacheKey(key, workspaceId))
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
