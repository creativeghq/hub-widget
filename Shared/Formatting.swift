import Foundation
import SwiftUI

enum Fmt {
    static func value(_ m: PulseMetric, compact: Bool = true) -> String {
        if m.isMoney {
            let style = FloatingPointFormatStyle<Double>.Currency(code: m.currency ?? "EUR")
                .precision(.fractionLength(0))
            return compact && abs(m.value) >= 10_000
                ? m.value.formatted(style.notation(.compactName))
                : m.value.formatted(style)
        }
        return compact && m.value >= 10_000
            ? m.value.formatted(.number.notation(.compactName))
            : m.value.formatted(.number.precision(.fractionLength(0)))
    }

    static func ago(_ date: Date?) -> String {
        guard let date else { return "never" }
        return date.formatted(.relative(presentation: .named))
    }

    /// `2026-11-20` → `20 Nov`.
    static func day(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: String(iso.prefix(10))) else { return iso }
        return d.formatted(.dateTime.day().month(.abbreviated))
    }
}

enum SectionStyle {
    static func symbol(_ key: String) -> String {
        switch key {
        case "tasks": return "checklist"
        case "projects": return "folder"
        case "finance": return "eurosign.circle"
        case "quotes": return "doc.text"
        case "crm": return "person.2"
        case "deals": return "chart.line.uptrend.xyaxis"
        case "realestate": return "house"
        case "warehouse": return "shippingbox"
        case "hr": return "person.badge.clock"
        case "inbox": return "tray"
        default: return "square.grid.2x2"
        }
    }

    static let attention = Color.orange
}
