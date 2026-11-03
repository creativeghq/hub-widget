import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Building blocks

enum Look {
    static let radius: CGFloat = 10
    static let fill = Color.primary.opacity(0.06)
    static let hairline = Color.primary.opacity(0.10)
}

/// A surface that reads as pressable: tinted fill + hairline, accent-tinted when it needs attention.
struct TileBackground: ViewModifier {
    let accent: Color
    var attention = false

    func body(content: Content) -> some View {
        content
            .background(attention ? accent.opacity(0.12) : Look.fill, in: RoundedRectangle(cornerRadius: Look.radius))
            .overlay(RoundedRectangle(cornerRadius: Look.radius)
                .strokeBorder(attention ? accent.opacity(0.45) : Look.hairline, lineWidth: 0.75))
    }
}

extension View {
    func tile(_ accent: Color, attention: Bool = false) -> some View { modifier(TileBackground(accent: accent, attention: attention)) }
}

struct SectionLabel: View {
    let section: PulseSection
    let accent: Color
    var font: Font = .footnote.weight(.semibold)
    /// Shows the chevron that says "this opens".
    var opens = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: SectionStyle.symbol(section.key))
                .foregroundStyle(section.attentionCount > 0 ? accent : .secondary)
            Text(section.title).lineLimit(1)
            if opens {
                Spacer(minLength: 2)
                Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .font(font)
    }
}

struct MetricLine: View {
    let metric: PulseMetric
    let accent: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(metric.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 4)
            if metric.needsAttention { Circle().fill(accent).frame(width: 5, height: 5) }
            Text(Fmt.value(metric))
                .font(.callout.weight(.semibold)).monospacedDigit()
                .foregroundStyle(metric.needsAttention ? accent : .primary)
        }
    }
}

/// Figures as equal-width boxes: value on top, label under it.
struct StatRow: View {
    let metrics: [PulseMetric]
    let accent: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(metrics) { m in
                VStack(alignment: .leading, spacing: 1) {
                    Text(Fmt.value(m))
                        .font(.headline).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(m.needsAttention ? accent : .primary)
                    Text(m.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(m.needsAttention ? accent.opacity(0.10) : Look.fill, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

/// A small tinted tag for a record's status.
struct StatusTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium)).lineLimit(1)
            .padding(.horizontal, 5).padding(.vertical, 1)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct ItemRow: View {
    let item: PulseItem
    let accent: Color
    var compact = false

    var body: some View {
        Link(destination: HubStore.widgetLink(item.url)) {
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(item.needsAttention ? accent : Color.secondary.opacity(0.35))
                    .frame(width: 3)
                    .padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(item.title).font(.footnote.weight(.medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        if let v = item.value {
                            Text(Fmt.money(v, currency: item.currency)).font(.footnote.weight(.semibold)).monospacedDigit()
                        }
                    }
                    if !compact {
                        HStack(spacing: 5) {
                            if let s = Fmt.status(item.status) {
                                StatusTag(text: s, tint: item.needsAttention ? accent : .secondary)
                            }
                            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Image(systemName: "arrow.up.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, compact ? 3 : 4)
            .contentShape(Rectangle())
        }
    }

    private var detail: String {
        [item.subtitle, Fmt.day(item.date)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// A list in a panel: rows split by hairlines, and a footer saying how many more wait in Hub.
struct ItemList: View {
    let items: [PulseItem]
    let limit: Int
    let accent: Color
    let moreURL: String
    var compact = false

    var body: some View {
        let shown = Array(items.prefix(max(0, limit)))
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().overlay(Look.hairline).padding(.leading, 18) }
                ItemRow(item: item, accent: accent, compact: compact)
            }
            if items.count > shown.count {
                Divider().overlay(Look.hairline)
                Link(destination: HubStore.widgetLink(moreURL)) {
                    HStack(spacing: 4) {
                        Text("+\(items.count - shown.count) more")
                        Spacer(minLength: 4)
                        Text("Open in Hub")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 2)
        .tile(accent)
    }
}

struct FailedNote: View {
    let text: String?
    var body: some View {
        Label(text ?? "Could not read this section.", systemImage: "exclamationmark.triangle")
            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
    }
}

struct Footer: View {
    let entry: PulseEntry
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            if entry.isStale { Image(systemName: "wifi.exclamationmark").foregroundStyle(accent) }
            Text(entry.pulse?.workspace?.name ?? "").lineLimit(1)
            Spacer(minLength: 4)
            Text(entry.isStale ? "Last good \(Fmt.ago(entry.pulse?.asOf))" : "Updated \(Fmt.ago(entry.pulse?.asOf))")
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
}

struct BannerLine: View {
    let banner: WidgetLayout.Banner
    let accent: Color

    var body: some View {
        Link(destination: HubStore.widgetLink(banner.url)) {
            Label(banner.text, systemImage: banner.tone == "attention" ? "exclamationmark.circle.fill" : "info.circle")
                .font(.caption.weight(.medium))
                .foregroundStyle(banner.tone == "attention" ? accent : .primary)
                .lineLimit(1)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

/// A small tinted button for a header ("All", "Open").
struct HeaderChip: View {
    let text: String
    let symbol: String
    let accent: Color
    var trailingSymbol = false

    var body: some View {
        HStack(spacing: 3) {
            if !trailingSymbol { Image(systemName: symbol) }
            Text(text)
            if trailingSymbol { Image(systemName: symbol) }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(accent)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }
}

/// What to show instead of numbers: no key, never loaded, or a section this login cannot see.
struct MessageView: View {
    let symbol: String
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).font(.title3).foregroundStyle(.secondary)
            Text(title).font(.callout.weight(.semibold))
            if let detail { Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(4) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    static func forMissing(_ entry: PulseEntry) -> MessageView {
        if let error = entry.error { return MessageView(symbol: "key", title: "Hub", detail: error) }
        return MessageView(symbol: "hourglass", title: "Loading…", detail: nil)
    }
}

extension PulseSection {
    /// The metric a one-line summary should lead with: the first that needs attention, else the first.
    var headline: PulseMetric? { metrics.first { $0.needsAttention } ?? metrics.first }
}
