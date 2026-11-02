import Foundation
import Security

/// Settings and the last good pulse, shared by the app and the widget extension through the App Group.
/// The API key lives in the Keychain under the same group, never in UserDefaults.
enum HubStore {
    static let defaultAPIBase = "https://bgbavxtjlbvgplozizxu.supabase.co/functions/v1"
    static let defaultAppBase = "https://app.materialshub.gr"

    /// `$(TeamIdentifierPrefix)com.creativeghq.hubwidget`, resolved at build time into Info.plist.
    static let appGroup: String = {
        let raw = Bundle.main.object(forInfoDictionaryKey: "HubAppGroup") as? String ?? ""
        return raw.isEmpty || raw.contains("$(") ? "com.creativeghq.hubwidget" : raw
    }()

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    private enum Key {
        static let apiBase = "apiBase"
        static let appBase = "appBase"
        static let workspaceId = "workspaceId"
        static let hiddenSections = "hiddenSections"
        static let lastPulse = "lastPulse"
        static let lastError = "lastError"
    }

    static var apiBase: String {
        get { nonEmpty(defaults.string(forKey: Key.apiBase)) ?? defaultAPIBase }
        set { defaults.set(trimSlash(newValue), forKey: Key.apiBase) }
    }

    static var appBase: String {
        get { nonEmpty(defaults.string(forKey: Key.appBase)) ?? defaultAppBase }
        set { defaults.set(trimSlash(newValue), forKey: Key.appBase) }
    }

    /// nil = let the server pick (the key's bound workspace, else your most recent one).
    static var workspaceId: String? {
        get { nonEmpty(defaults.string(forKey: Key.workspaceId)) }
        set { defaults.set(newValue, forKey: Key.workspaceId) }
    }

    static var hiddenSections: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.hiddenSections) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.hiddenSections) }
    }

    static var lastPulse: Pulse? {
        get {
            guard let data = defaults.data(forKey: Key.lastPulse) else { return nil }
            return try? JSONDecoder.pulse.decode(Pulse.self, from: data)
        }
        set {
            let data = newValue.flatMap { try? JSONEncoder.pulse.encode($0) }
            defaults.set(data, forKey: Key.lastPulse)
        }
    }

    static var lastError: String? {
        get { defaults.string(forKey: Key.lastError) }
        set { defaults.set(newValue, forKey: Key.lastError) }
    }

    /// A deep link into the web app. `path` is the section/metric `url` the server sent.
    static func appURL(_ path: String?) -> URL? {
        let p = path ?? "/"
        return URL(string: appBase + (p.hasPrefix("/") ? p : "/" + p))
    }

    /// The widget cannot open a browser URL itself on every macOS version; it hands the path to the app.
    static func widgetLink(_ path: String?) -> URL {
        var c = URLComponents()
        c.scheme = "hubwidget"
        c.host = "open"
        c.queryItems = [URLQueryItem(name: "path", value: path ?? "/")]
        return c.url ?? URL(string: "hubwidget://open")!
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    private static func trimSlash(_ s: String) -> String {
        var out = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while out.hasSuffix("/") { out.removeLast() }
        return out
    }
}

extension JSONEncoder {
    static let pulse: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .useDefaultKeys
        return e
    }()
}

/// The `kai_` API key, in the data-protection Keychain shared through the App Group.
enum APIKeyStore {
    private static let service = "com.creativeghq.hubwidget"
    private static let account = "kai-api-key"

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: HubStore.appGroup,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    static func read() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func save(_ key: String) -> OSStatus {
        let data = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let update = SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return update }
        var add = baseQuery()
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(add as CFDictionary, nil)
    }

    static func delete() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
