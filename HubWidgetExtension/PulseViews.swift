import SwiftUI
import WidgetKit

// MARK: - Building blocks

struct SectionLabel: View {
    let section: PulseSection
    var font: Font = .caption.weight(.semibold)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: SectionStyle.symbol(section.key))
                .foregroundStyle(section.attentionCount > 0 ? SectionStyle.attention : .secondary)
            Text(section.title).lineLimit(1)
        }
        .font(font)
    }
}

struct MetricLine: View {
    let metric: PulseMetric
    var valueFont: Font = .callout.weight(.semibold)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(metric.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if metric.needsAttention {
                Circle().fill(SectionStyle.attention).frame(width: 5, height: 5)
            }
            Text(Fmt.value(metric))
                .font(valueFont)
                .monospacedDigit()
                .foregroundStyle(metric.needsAttention ? SectionStyle.attention : .primary)
        }
    }
}

struct FailedNote: View {
    let text: String?
    var body: some View {
        Label(text ?? "Could not read this section.", systemImage: "exclamationmark.triangle")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
    }
}

struct Footer: View {
    let entry: PulseEntry
    var body: some View {
        HStack(spacing: 4) {
            if entry.isStale {
                Image(systemName: "wifi.exclamationmark").foregroundStyle(SectionStyle.attention)
            }
            Text(entry.pulse?.workspace?.name ?? "")
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(entry.isStale ? "Last good \(Fmt.ago(entry.pulse?.asOf))" : "Updated \(Fmt.ago(entry.pulse?.asOf))")
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
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
        if let error = entry.error {
            return MessageView(symbol: "key", title: "Hub Widget", detail: error)
        }
        return MessageView(symbol: "hourglass", title: "Loading…", detail: nil)
    }
}

/// The metric a one-line summary should lead with: the first that needs attention, else the first.
extension PulseSection {
    var headline: PulseMetric? { metrics.first { $0.needsAttention } ?? metrics.first }
}

// MARK: - Overview widget

struct OverviewView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    var body: some View {
        if entry.pulse == nil {
            MessageView.forMissing(entry)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                header
                switch family {
                case .systemMedium: tiles(limit: 6, columns: 3)
                case .systemExtraLarge: cards
                default: rows
                }
                Spacer(minLength: 0)
                Footer(entry: entry)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Hub").font(.headline)
            Spacer()
            let n = entry.pulse?.attention ?? 0
            Text(n == 0 ? "All clear" : "\(n) need\(n == 1 ? "s" : "") attention")
                .font(.caption.weight(.semibold))
                .foregroundStyle(n == 0 ? Color.secondary : SectionStyle.attention)
        }
    }

    private func tiles(limit: Int, columns: Int) -> some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .topLeading), count: columns)
        return LazyVGrid(columns: grid, alignment: .leading, spacing: 8) {
            ForEach(entry.visibleSections.prefix(limit)) { section in
                Link(destination: HubStore.widgetLink(section.headline?.url ?? section.url)) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(section: section, font: .caption2.weight(.semibold))
                        if section.failed {
                            Text("Unknown").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                        } else if let m = section.headline {
                            Text(Fmt.value(m))
                                .font(.title3.weight(.semibold)).monospacedDigit()
                                .foregroundStyle(m.needsAttention ? SectionStyle.attention : .primary)
                            Text(m.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(entry.visibleSections.prefix(8)) { section in
                Link(destination: HubStore.widgetLink(section.url)) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(section: section)
                        if section.failed {
                            FailedNote(text: section.note)
                        } else {
                            HStack(spacing: 10) {
                                ForEach(section.metrics.prefix(3)) { m in
                                    HStack(spacing: 3) {
                                        Text(Fmt.value(m)).font(.caption.weight(.semibold)).monospacedDigit()
                                            .foregroundStyle(m.needsAttention ? SectionStyle.attention : .primary)
                                        Text(m.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                }
                Divider()
            }
        }
    }

    private var cards: some View {
        let grid = [GridItem(.flexible(), spacing: 12, alignment: .topLeading),
                    GridItem(.flexible(), spacing: 12, alignment: .topLeading)]
        return LazyVGrid(columns: grid, alignment: .leading, spacing: 12) {
            ForEach(entry.visibleSections) { section in
                SectionCard(section: section, maxMetrics: 4, maxItems: 2)
            }
        }
    }
}

struct SectionCard: View {
    let section: PulseSection
    var maxMetrics = 6
    var maxItems = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Link(destination: HubStore.widgetLink(section.url)) { SectionLabel(section: section) }
            if section.failed {
                FailedNote(text: section.note)
            } else {
                ForEach(section.metrics.prefix(maxMetrics)) { m in
                    Link(destination: HubStore.widgetLink(m.url ?? section.url)) { MetricLine(metric: m, valueFont: .caption.weight(.semibold)) }
                }
                ForEach(section.items.prefix(maxItems)) { item in
                    HStack {
                        Text(item.title).font(.caption2).lineLimit(1)
                        Spacer(minLength: 4)
                        if let d = Fmt.day(item.date) { Text(d).font(.caption2).foregroundStyle(.secondary) }
                    }
                }
                if let note = section.note {
                    Text(note).font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Single-section widget

struct SectionView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    var body: some View {
        if entry.pulse == nil {
            MessageView.forMissing(entry)
        } else if let kind = entry.section, let section = entry.pulse?.section(kind.rawValue) {
            content(section)
        } else {
            unavailable
        }
    }

    @ViewBuilder
    private func content(_ section: PulseSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(section: section, font: .caption.weight(.semibold))
            if section.failed {
                FailedNote(text: section.note)
            } else if family == .systemSmall {
                if let lead = section.headline {
                    Text(Fmt.value(lead))
                        .font(.title.weight(.semibold)).monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1)
                        .foregroundStyle(lead.needsAttention ? SectionStyle.attention : .primary)
                    Text(lead.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                ForEach(section.metrics.filter { $0.key != section.headline?.key }.prefix(2)) { m in
                    MetricLine(metric: m, valueFont: .caption.weight(.semibold))
                }
            } else {
                SectionCard(section: section, maxMetrics: 6, maxItems: family == .systemLarge ? 6 : 2)
            }
            Spacer(minLength: 0)
            Footer(entry: entry)
        }
        .widgetURL(HubStore.widgetLink(section.url))
    }

    private var unavailable: some View {
        let kind = entry.section ?? .finance
        let hidden = entry.pulse?.unavailable.first { $0.key == kind.rawValue }
        let detail: String
        switch hidden?.reason {
        case "not_entitled": detail = "This workspace does not have the \(kind.title) module."
        case "no_capability": detail = "Your role in this workspace cannot see \(kind.title)."
        default: detail = "Nothing to show for \(kind.title)."
        }
        return MessageView(symbol: "eye.slash", title: kind.title, detail: detail)
    }
}
