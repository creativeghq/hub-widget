import Foundation
import SwiftUI

enum Fmt {
    static func value(_ m: PulseMetric, compact: Bool = true) -> String {
        if m.isPercent {
            return (m.value > 0 ? "+" : "") + m.value.formatted(.number.precision(.fractionLength(0...1))) + "%"
        }
        if m.isMoney {
            let code = m.currency ?? "EUR"
            guard compact && abs(m.value) >= 10_000 else {
                return m.value.formatted(.currency(code: code).precision(.fractionLength(0)))
            }
            // Compact currency notation is macOS 15+ in extensions; symbol + compact number is the same text.
            return symbol(for: code) + m.value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        }
        return compact && m.value >= 10_000
            ? m.value.formatted(.number.notation(.compactName))
            : m.value.formatted(.number.precision(.fractionLength(0)))
    }

    static func symbol(for code: String) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        return f.currencySymbol ?? code + " "
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

extension Fmt {
    /// A task's due line from the server's bucket: "Overdue · 31 Oct", "Today", "Tomorrow", "6 Nov".
    static func due(_ item: PulseItem) -> String {
        switch item.bucket {
        case "overdue": return ["Overdue", day(item.date)].compactMap { $0 }.joined(separator: " · ")
        case "today": return "Today"
        case "tomorrow": return "Tomorrow"
        default: return day(item.date) ?? "No date"
        }
    }

    /// `in_progress` → `In progress`.
    static func status(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let words = raw.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }

    static func money(_ value: Double, currency: String?) -> String {
        let code = currency ?? "EUR"
        if abs(value) >= 10_000 {
            return symbol(for: code) + value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        }
        return value.formatted(.currency(code: code).precision(.fractionLength(0)))
    }
}

extension Color {
    /// `#F59E0B` → Color; nil for anything else.
    init?(hex: String?) {
        guard var h = hex?.trimmingCharacters(in: .whitespaces), !h.isEmpty else { return nil }
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

enum SectionStyle {
    static func symbol(_ key: String) -> String {
        switch key {
        case "today": return "sun.max"
        case "analytics": return "chart.bar.xaxis"
        case "appointments": return "calendar"
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
        case "jobs": return "briefcase"
        case "marketing": return "megaphone"
        case "agent": return "sparkles"
        case "social": return "bubble.left.and.bubble.right"
        case "updates": return "gift"
        case "system": return "gearshape"
        case "account": return "person.crop.circle"
        case "general": return "bell"
        default: return "square.grid.2x2"
        }
    }

    /// A notification category's name, for the banner subtitle.
    static func label(_ key: String?) -> String? {
        switch key {
        case "inbox": return "Inbox"
        case "crm": return "CRM"
        case "finance": return "Finance"
        case "quotes": return "Quotes"
        case "projects": return "Projects"
        case "tasks": return "Tasks"
        case "warehouse": return "Warehouse"
        case "hr": return "HR"
        case "realestate": return "Real estate"
        case "deals": return "Deals"
        case "analytics": return "Analytics"
        case "appointments": return "Appointments"
        case "jobs": return "Jobs"
        case "marketing": return "Marketing"
        case "agent": return "Assistant"
        case "social": return "Social"
        case "updates": return "What's new"
        case "system": return "System"
        case "account": return "Account"
        default: return nil
        }
    }

    /// An area's own colour: its app icon on the widget and its notifications' badge.
    static func tint(_ key: String?) -> Color {
        switch key {
        case "today": return .orange
        case "tasks": return .blue
        case "appointments": return .red
        case "projects": return .indigo
        case "finance": return .green
        case "quotes": return Color(red: 0.80, green: 0.56, blue: 0.0)
        case "crm": return .teal
        case "analytics": return .purple
        case "deals": return .mint
        case "realestate": return .brown
        case "warehouse": return Color(red: 0.42, green: 0.48, blue: 0.56)
        case "hr": return .pink
        case "inbox": return .cyan
        case "jobs": return .mint
        case "marketing": return .red
        case "agent": return .cyan
        case "social": return .blue
        default: return .gray
        }
    }

    static let attention = Color.orange

    static func accent(_ layout: WidgetLayout?) -> Color { Color(hex: layout?.attentionColor) ?? attention }
}
