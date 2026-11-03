import Foundation

enum PulseError: LocalizedError, Equatable {
    case noKey
    case badURL
    case http(Int, String)
    case transport(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .noKey: return "Right-click this widget → Edit Widget, and paste your kai_ API key."
        case .badURL: return "The API address is not a valid URL."
        case .http(401, _): return "The API key was refused. Check it is active in Profile → Keys."
        case .http(404, _): return "That workspace was not found for this key."
        case .http(let code, let msg): return "The platform answered \(code): \(msg)"
        case .transport(let msg): return "Could not reach the platform: \(msg)"
        case .decoding(let msg): return "Unexpected answer from the platform: \(msg)"
        }
    }
}

struct PulseClient {
    let apiKey: String
    var workspaceId: String?
    var apiBase: String = HubStore.apiBase
    var session: URLSession = .shared

    func fetch() async throws -> Pulse {
        var query: [URLQueryItem] = []
        if let ws = workspaceId { query.append(URLQueryItem(name: "workspace_id", value: ws)) }
        return try JSONDecoder.pulse.decode(Pulse.self, from: try await get(query))
    }

    /// The caller's platform notifications newer than `since` (nil = start from now, no backlog).
    func notifications(since: String?) async throws -> NotificationFeed {
        var query = [URLQueryItem(name: "view", value: "notifications")]
        if let since { query.append(URLQueryItem(name: "since", value: since)) }
        return try JSONDecoder().decode(NotificationFeed.self, from: try await get(query))
    }

    /// Adds a CRM lead. The platform decides whether this login may.
    func createLead(_ lead: LeadDraft) async throws -> String {
        var body: [String: Any] = ["action": "create_lead", "lead": lead.payload]
        if let ws = workspaceId { body["workspace_id"] = ws }
        let data = try await send(query: [], body: body)
        let reply = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (reply?["url"] as? String) ?? "/crm?tab=leads"
    }

    /// Marks a task done (an item whose `action` is `complete_task`).
    func completeTask(_ taskId: String) async throws {
        var body: [String: Any] = ["action": "complete_task", "task_id": taskId]
        if let ws = workspaceId { body["workspace_id"] = ws }
        _ = try await send(query: [], body: body)
    }

    private func get(_ query: [URLQueryItem]) async throws -> Data {
        try await send(query: query, body: nil)
    }

    private func send(query: [URLQueryItem], body: [String: Any]?) async throws -> Data {
        guard !apiKey.isEmpty else { throw PulseError.noKey }
        guard var comps = URLComponents(string: apiBase + "/workspace-pulse") else { throw PulseError.badURL }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw PulseError.badURL }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.httpMethod = body == nil ? "GET" : "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw PulseError.transport(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw PulseError.http(status, message ?? HTTPURLResponse.localizedString(forStatusCode: status))
        }
        return data
    }

    /// Fetch with the widget's key (or the remembered one), cache the result, and fall back to the
    /// last good pulse — marked by the returned error — when the platform cannot be reached.
    static func refresh(key configured: String?, workspaceId: String?, maxAge: TimeInterval = 0) async -> (pulse: Pulse?, error: String?) {
        guard let key = HubStore.nonEmpty(configured) ?? HubStore.rememberedKey else {
            return (nil, PulseError.noKey.localizedDescription)
        }
        if maxAge > 0, let fresh = HubStore.freshPulse(key: key, workspaceId: workspaceId, maxAge: maxAge) {
            return (fresh, nil)
        }
        do {
            let pulse = try await PulseClient(apiKey: key, workspaceId: workspaceId).fetch()
            HubStore.rememberedKey = key
            HubStore.storeCache(pulse, key: key, workspaceId: workspaceId)
            return (pulse, nil)
        } catch {
            return (HubStore.cachedPulse(key: key, workspaceId: workspaceId), error.localizedDescription)
        }
    }
}

struct NotificationFeed: Decodable {
    let notifications: [PlatformNotification]
    let cursor: String?
}

struct PlatformNotification: Decodable, Identifiable {
    let id: String
    let type: String?
    let title: String?
    let body: String?
    let actionUrl: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, type, title, body
        case actionUrl = "action_url"
        case createdAt = "created_at"
    }
}

/// What the quick-add form sends. Empty fields are left out; the server trims and validates.
struct LeadDraft: Equatable {
    var name = ""
    var phone = ""
    var email = ""
    var company = ""
    var request = ""
    var source = "phone"
    var followUp: Date?
    var value = ""

    static let sources: [(key: String, label: String)] = [
        ("phone", "Phone"), ("walk_in", "Walk-in"), ("email", "Email"), ("website", "Website"),
        ("referral", "Referral"), ("social", "Social"), ("other", "Other"),
    ]

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var payload: [String: Any] {
        var p: [String: Any] = ["name": name, "source": source]
        for (k, v) in [("phone", phone), ("email", email), ("company_name", company), ("request", request)]
        where !v.trimmingCharacters(in: .whitespaces).isEmpty { p[k] = v }
        if let followUp { p["follow_up_on"] = Self.localDay(followUp) }
        if let n = Double(value.replacingOccurrences(of: ",", with: ".")), n >= 0 { p["estimated_value"] = n }
        return p
    }

    /// The operator's calendar day, never UTC: a follow-up set after midnight must not land on yesterday.
    static func localDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
