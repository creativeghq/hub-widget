import Foundation

/// The `workspace-pulse` response. Every figure is derived on the server; the widget only formats.
struct Pulse: Codable, Equatable {
    let ok: Bool
    let workspace: WorkspaceRef?
    let asOf: Date?
    let attention: Int
    let sections: [PulseSection]
    let unavailable: [UnavailableSection]
    let workspaces: [WorkspaceRef]
    let layout: WidgetLayout

    enum CodingKeys: String, CodingKey {
        case ok, workspace, attention, sections, unavailable, workspaces, layout
        case asOf = "as_of"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        workspace = try c.decodeIfPresent(WorkspaceRef.self, forKey: .workspace)
        asOf = try c.decodeIfPresent(Date.self, forKey: .asOf)
        attention = try c.decodeIfPresent(Int.self, forKey: .attention) ?? 0
        sections = try c.decodeIfPresent([PulseSection].self, forKey: .sections) ?? []
        unavailable = try c.decodeIfPresent([UnavailableSection].self, forKey: .unavailable) ?? []
        workspaces = try c.decodeIfPresent([WorkspaceRef].self, forKey: .workspaces) ?? []
        layout = (try? c.decodeIfPresent(WidgetLayout.self, forKey: .layout)) ?? WidgetLayout()
    }

    func section(_ key: String) -> PulseSection? { sections.first { $0.key == key } }

    /// Sections in the order the server's layout asks for; unknown keys keep their server order at the end.
    var orderedSections: [PulseSection] {
        let rank = Dictionary(layout.order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return sections.enumerated()
            .sorted { (rank[$0.element.key] ?? 1000 + $0.offset) < (rank[$1.element.key] ?? 1000 + $1.offset) }
            .map(\.element)
    }
}

struct WorkspaceRef: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let name: String
}

struct PulseSection: Codable, Equatable, Identifiable {
    let key: String
    let title: String
    /// `ok` or `failed`. A failed section has no metrics and says why in `note` — it is unknown, not zero.
    let status: String
    let url: String
    let note: String?
    let metrics: [PulseMetric]
    let items: [PulseItem]

    var id: String { key }
    var failed: Bool { status != "ok" }
    var attentionCount: Int { metrics.filter(\.needsAttention).count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? key
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "failed"
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? "/"
        note = try c.decodeIfPresent(String.self, forKey: .note)
        metrics = try c.decodeIfPresent([PulseMetric].self, forKey: .metrics) ?? []
        items = try c.decodeIfPresent([PulseItem].self, forKey: .items) ?? []
    }
}

struct PulseMetric: Codable, Equatable, Identifiable {
    let key: String
    let label: String
    let value: Double
    /// `count` or `money`.
    let kind: String
    let currency: String?
    /// `attention` or `neutral`. Set by the server, never inferred here.
    let tone: String
    let url: String?

    var id: String { key }
    var needsAttention: Bool { tone == "attention" }
    var isMoney: Bool { kind == "money" }
}

struct PulseItem: Codable, Equatable, Identifiable {
    let title: String
    let subtitle: String?
    let status: String?
    let date: String?
    let url: String?
    let tone: String?
    let value: Double?
    let currency: String?
    /// The record's id, sent only when the widget may act on it (see `action`).
    let recordId: String?
    /// `complete_task`, or nil when the row only opens.
    let action: String?

    enum CodingKeys: String, CodingKey {
        case title, subtitle, status, date, url, tone, value, currency, action
        case recordId = "id"
    }

    var id: String { (recordId ?? url ?? "") + title + (date ?? "") }
    var needsAttention: Bool { tone == "attention" }
    var canComplete: Bool { action == "complete_task" && recordId != nil }
}

struct UnavailableSection: Codable, Equatable {
    let key: String
    let title: String
    /// `not_entitled` (workspace has not got the module) or `no_capability` (your role cannot see it).
    let reason: String
}

extension JSONDecoder {
    static let pulse: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = PulseDate.parse(raw) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(raw)"))
        }
        return d
    }()
}

enum PulseDate {
    /// Postgres emits `2026-11-02T17:50:36.266712+00:00` — microseconds, which ISO8601DateFormatter rejects.
    static func parse(_ raw: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let d = plain.date(from: raw) { return d }
        let trimmed = raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: trimmed)
    }
}
