import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Building blocks

struct SectionLabel: View {
    let section: PulseSection
    let accent: Color
    var font: Font = .caption.weight(.semibold)

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: SectionStyle.symbol(section.key))
                .foregroundStyle(section.attentionCount > 0 ? accent : .secondary)
            Text(section.title).lineLimit(1)
        }
        .font(font)
    }
}

struct MetricLine: View {
    let metric: PulseMetric
    let accent: Color
    var valueFont: Font = .caption.weight(.semibold)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(metric.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 4)
            if metric.needsAttention { Circle().fill(accent).frame(width: 5, height: 5) }
            Text(Fmt.value(metric))
                .font(valueFont).monospacedDigit()
                .foregroundStyle(metric.needsAttention ? accent : .primary)
        }
    }
}

/// `value label` pairs on one line, e.g. "2 Overdue · 5 Due in 7 days".
struct MetricStrip: View {
    let metrics: [PulseMetric]
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            ForEach(metrics) { m in
                HStack(spacing: 3) {
                    Text(Fmt.value(m)).font(.caption.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(m.needsAttention ? accent : .primary)
                    Text(m.label).font(.caption2).foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
        }
    }
}

struct ItemRow: View {
    let item: PulseItem
    let accent: Color

    var body: some View {
        Link(destination: HubStore.widgetLink(item.url)) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if item.needsAttention { Circle().fill(accent).frame(width: 5, height: 5) }
                    Text(item.title).font(.caption.weight(.medium)).lineLimit(1)
                    Spacer(minLength: 4)
                    if let v = item.value {
                        Text(Fmt.money(v, currency: item.currency)).font(.caption.weight(.semibold)).monospacedDigit()
                    }
                }
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var detail: String {
        [item.subtitle, Fmt.status(item.status), Fmt.day(item.date)].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct FailedNote: View {
    let text: String?
    var body: some View {
        Label(text ?? "Could not read this section.", systemImage: "exclamationmark.triangle")
            .font(.caption2).foregroundStyle(.secondary).lineLimit(2)
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

// MARK: - Overview widget

struct OverviewView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    private var accent: Color { SectionStyle.accent(entry.layout) }

    var body: some View {
        if entry.pulse == nil {
            MessageView.forMissing(entry)
        } else if let key = entry.drill, let section = entry.pulse?.section(key) {
            DrillView(entry: entry, section: section, accent: accent)
        } else {
            VStack(alignment: .leading, spacing: family == .systemMedium ? 6 : 8) {
                header
                if family != .systemMedium, let banner = entry.layout.banner { BannerLine(banner: banner, accent: accent) }
                switch family {
                case .systemMedium: tiles
                case .systemExtraLarge: cards
                default: rows
                }
                Spacer(minLength: 0)
                if family != .systemMedium { Footer(entry: entry, accent: accent) }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Hub").font(.headline)
            if family == .systemMedium {
                Text(Fmt.ago(entry.pulse?.asOf)).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            let n = entry.pulse?.attention ?? 0
            Text(n == 0 ? "All clear" : "\(n) need\(n == 1 ? "s" : "") attention")
                .font(.caption.weight(.semibold))
                .foregroundStyle(n == 0 ? Color.secondary : accent)
        }
    }

    private var tiles: some View {
        let size = entry.layout.overview.medium
        let limit = FitLimits.overviewMedium
        let count = FitLimits.clamp(size.maxSections, 6, max: limit.sections)
        let columns = max(1, FitLimits.clamp(size.columns, 3, max: limit.columns))
        let grid = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .topLeading), count: columns)
        return LazyVGrid(columns: grid, alignment: .leading, spacing: 8) {
            ForEach(entry.visibleSections.prefix(count)) { section in
                Button(intent: OpenSectionIntent(section: section.key)) {
                    VStack(alignment: .leading, spacing: 2) {
                        SectionLabel(section: section, accent: accent, font: .caption2.weight(.semibold))
                        if section.failed {
                            Text("Unknown").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                        } else if let m = section.headline {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(Fmt.value(m)).font(.headline).monospacedDigit()
                                    .foregroundStyle(m.needsAttention ? accent : .primary)
                                Text(m.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rows: some View {
        let size = entry.layout.overview.large
        let limit = FitLimits.overviewLarge
        let count = FitLimits.clamp(size.maxSections, 6, max: limit.sections - (entry.layout.banner == nil ? 0 : 1))
        let metrics = FitLimits.clamp(size.metrics, 3, max: limit.metrics)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.visibleSections.prefix(count)) { section in
                Button(intent: OpenSectionIntent(section: section.key)) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            SectionLabel(section: section, accent: accent)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        if section.failed {
                            FailedNote(text: section.note)
                        } else {
                            MetricStrip(metrics: Array(section.metrics.prefix(metrics)), accent: accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cards: some View {
        let size = entry.layout.overview.extraLarge
        let limit = FitLimits.overviewExtraLarge
        let sections = Array(entry.visibleSections.prefix(FitLimits.clamp(size.maxSections, 12, max: limit.sections)))
        let columns = max(1, FitLimits.clamp(size.columns, 3, max: limit.columns))
        var metrics = FitLimits.clamp(size.metrics, 3, max: limit.metrics)
        var items = FitLimits.clamp(size.items, 0, max: limit.items)
        // Height budget: ~290pt of content, ~15pt a line, 10pt between card rows.
        let rows = max(1, Int(ceil(Double(sections.count) / Double(columns))))
        let linesPerCard = max(2, (290 - (rows - 1) * 10) / (rows * 15))
        while 1 + metrics + items > linesPerCard && items > 0 { items -= 1 }
        while 1 + metrics + items > linesPerCard && metrics > 1 { metrics -= 1 }
        let grid = Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .topLeading), count: columns)
        return LazyVGrid(columns: grid, alignment: .leading, spacing: 10) {
            ForEach(sections) { section in
                Button(intent: OpenSectionIntent(section: section.key)) {
                    SectionCard(section: section, accent: accent, maxMetrics: metrics, maxItems: items)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The overview zoomed into one section: its figures and its list, each row opening the record.
struct DrillView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry
    let section: PulseSection
    let accent: Color

    private var itemLimit: Int {
        let cap: Int
        switch family {
        case .systemMedium: cap = FitLimits.drillMedium
        case .systemExtraLarge: cap = FitLimits.drillExtraLarge
        default: cap = FitLimits.drillLarge
        }
        return FitLimits.clamp(entry.layout.drilldown.items, 6, max: cap)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(intent: CloseSectionIntent()) {
                    Label("All", systemImage: "chevron.left").font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                SectionLabel(section: section, accent: accent, font: .subheadline.weight(.semibold))
                Spacer()
                Link(destination: HubStore.widgetLink(section.url)) {
                    Image(systemName: "arrow.up.right.square").font(.caption)
                }
            }
            if section.failed {
                FailedNote(text: section.note)
            } else {
                MetricStrip(metrics: Array(section.metrics.prefix(family == .systemMedium ? 2 : 3)), accent: accent)
                if section.items.isEmpty {
                    Text("Nothing waiting here right now.").font(.caption).foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(section.items.prefix(itemLimit)) { ItemRow(item: $0, accent: accent) }
                    }
                }
            }
            Spacer(minLength: 0)
            if family != .systemMedium { Footer(entry: entry, accent: accent) }
        }
    }
}

struct SectionCard: View {
    let section: PulseSection
    let accent: Color
    var maxMetrics = 6
    var maxItems = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(section: section, accent: accent)
            if section.failed {
                FailedNote(text: section.note)
            } else {
                ForEach(section.metrics.prefix(maxMetrics)) { MetricLine(metric: $0, accent: accent) }
                ForEach(section.items.prefix(maxItems)) { ItemRow(item: $0, accent: accent) }
            }
        }
    }
}

// MARK: - Single-section widget

struct SectionView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    private var accent: Color { SectionStyle.accent(entry.layout) }

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
        let sizes = entry.layout.section
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel(section: section, accent: accent)
            if section.failed {
                FailedNote(text: section.note)
            } else if family == .systemSmall {
                if let lead = section.headline {
                    Text(Fmt.value(lead))
                        .font(.title2.weight(.semibold)).monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1)
                        .foregroundStyle(lead.needsAttention ? accent : .primary)
                    Text(lead.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                let more = FitLimits.clamp(sizes.small.metrics, 3, max: FitLimits.sectionSmall.metrics) - 1
                ForEach(section.metrics.filter { $0.key != section.headline?.key }.prefix(max(0, more))) {
                    MetricLine(metric: $0, accent: accent)
                }
            } else {
                let limit = family == .systemLarge ? FitLimits.sectionLarge : FitLimits.sectionMedium
                let size = family == .systemLarge ? sizes.large : sizes.medium
                SectionCard(section: section, accent: accent,
                            maxMetrics: FitLimits.clamp(size.metrics, limit.metrics, max: limit.metrics),
                            maxItems: FitLimits.clamp(size.items, limit.items, max: limit.items))
            }
            Spacer(minLength: 0)
            if family == .systemLarge { Footer(entry: entry, accent: accent) }
            else if entry.isStale { Image(systemName: "wifi.exclamationmark").font(.caption2).foregroundStyle(accent) }
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
