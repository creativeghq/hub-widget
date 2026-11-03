import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Fitting

/// Tries the richest version first and steps down until one fits the height the widget has, so a
/// widget never clips whatever the data or the server layout asks for.
struct FitDown<Content: View>: View {
    let steps: [Int]
    let content: (Int) -> Content

    init(from top: Int, floor: Int = 1, @ViewBuilder content: @escaping (Int) -> Content) {
        let t = max(floor, top)
        steps = [t, t - 1, t - 2, t - 4, floor].map { max(floor, $0) }
        self.content = content
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content(steps[0])
            content(steps[1])
            content(steps[2])
            content(steps[3])
            content(steps[4])
        }
    }
}

/// Splits a list into rows of `columns` for a non-lazy Grid (lazy grids report no size to ViewThatFits).
func chunked<T>(_ items: [T], _ columns: Int) -> [[T]] {
    let c = max(1, columns)
    return stride(from: 0, to: items.count, by: c).map { Array(items[$0..<min($0 + c, items.count)]) }
}

struct SectionTile: View {
    let section: PulseSection
    let accent: Color
    var big = false
    var secondary = false

    var body: some View {
        Button(intent: OpenSectionIntent(section: section.key)) {
            VStack(alignment: .leading, spacing: big ? 3 : 1) {
                SectionLabel(section: section, accent: accent,
                             font: big ? .footnote.weight(.semibold) : .caption.weight(.semibold), opens: true)
                if section.failed {
                    Text("Unknown").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                } else if let m = section.headline {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Fmt.value(m)).font(big ? .title2.weight(.semibold) : .headline).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(m.needsAttention ? accent : .primary)
                        Text(m.label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if secondary, let s = section.metrics.first(where: { $0.key != m.key }) {
                        Text("\(Fmt.value(s)) \(s.label)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, big ? 7 : 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tile(accent, attention: section.attentionCount > 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// `value label` pairs on one line, e.g. "2 Overdue · 5 Due in 7 days".
struct InlineMetrics: View {
    let metrics: [PulseMetric]
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            ForEach(metrics) { m in
                HStack(spacing: 3) {
                    Text(Fmt.value(m)).font(.callout.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(m.needsAttention ? accent : .primary)
                    Text(m.label).font(.caption).foregroundStyle(.secondary)
                }
                .lineLimit(1)
            }
        }
    }
}

struct SectionGrid<Cell: View>: View {
    let sections: [PulseSection]
    let columns: Int
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8
    @ViewBuilder let cell: (PulseSection) -> Cell

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: hSpacing, verticalSpacing: vSpacing) {
            ForEach(Array(chunked(sections, columns).enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(row) { cell($0) }
                    ForEach(0..<max(0, columns - row.count), id: \.self) { _ in
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
    }
}

// MARK: - Overview widget

struct OverviewView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    private var accent: Color { SectionStyle.accent(entry.layout) }

    /// Server order, with anything needing attention moved up so it survives when space runs out.
    private var sections: [PulseSection] {
        let all = entry.visibleSections
        return all.filter { $0.attentionCount > 0 } + all.filter { $0.attentionCount == 0 }
    }

    var body: some View {
        if entry.pulse == nil {
            MessageView.forMissing(entry)
        } else if let key = entry.drill, let section = entry.pulse?.section(key) {
            DrillView(entry: entry, section: section, accent: accent)
        } else {
            VStack(alignment: .leading, spacing: family == .systemMedium ? 6 : 8) {
                header
                if family != .systemMedium, let banner = entry.layout.banner {
                    BannerLine(banner: banner, accent: accent)
                }
                content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if family != .systemMedium { Footer(entry: entry, accent: accent) }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium: medium
        case .systemExtraLarge: extraLarge
        default:
            if entry.layout.overview.large.style == "rows" { largeRows } else { largeTiles }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Hub").font(family == .systemMedium ? .subheadline.weight(.bold) : .headline)
            if family == .systemMedium {
                Text(Fmt.ago(entry.pulse?.asOf)).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            let n = entry.pulse?.attention ?? 0
            if n == 0 {
                Label("All clear", systemImage: "checkmark.circle").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            } else {
                Text("\(n) need\(n == 1 ? "s" : "") attention")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private var medium: some View {
        let size = entry.layout.overview.medium
        let columns = max(1, FitLimits.clamp(size.columns, 3, max: FitLimits.overviewMedium.columns))
        let top = FitLimits.clamp(size.maxSections, 6, max: FitLimits.overviewMedium.sections)
        return FitDown(from: top) { n in
            SectionGrid(sections: Array(sections.prefix(n)), columns: columns, hSpacing: 6, vSpacing: 6) {
                SectionTile(section: $0, accent: accent)
            }
        }
    }

    private var largeTiles: some View {
        let size = entry.layout.overview.large
        let columns = max(1, FitLimits.clamp(size.columns, 2, max: FitLimits.overviewLarge.columns))
        let top = FitLimits.clamp(size.maxSections, 8, max: FitLimits.overviewLarge.sections)
        let secondary = (size.metrics ?? 2) > 1
        return ViewThatFits(in: .vertical) {
            largeTileGrid(top, columns: columns, secondary: secondary)
            largeTileGrid(top, columns: columns, secondary: false)
            largeTileGrid(max(1, top - 2), columns: columns, secondary: false)
            largeTileGrid(max(1, top - 4), columns: columns, secondary: false)
        }
    }

    private func largeTileGrid(_ count: Int, columns: Int, secondary: Bool) -> some View {
        SectionGrid(sections: Array(sections.prefix(count)), columns: columns) {
            SectionTile(section: $0, accent: accent, big: true, secondary: secondary)
        }
    }

    private var largeRows: some View {
        let size = entry.layout.overview.large
        let top = FitLimits.clamp(size.maxSections, 6, max: FitLimits.overviewLarge.sections)
        let metrics = FitLimits.clamp(size.metrics, 3, max: FitLimits.overviewLarge.metrics)
        return FitDown(from: top) { n in
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sections.prefix(n)) { section in
                    Button(intent: OpenSectionIntent(section: section.key)) {
                        VStack(alignment: .leading, spacing: 2) {
                            SectionLabel(section: section, accent: accent, opens: true)
                            if section.failed {
                                FailedNote(text: section.note)
                            } else {
                                InlineMetrics(metrics: Array(section.metrics.prefix(metrics)), accent: accent)
                            }
                        }
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .tile(accent, attention: section.attentionCount > 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var extraLarge: some View {
        let size = entry.layout.overview.extraLarge
        let limit = FitLimits.overviewExtraLarge
        let columns = max(1, FitLimits.clamp(size.columns, 3, max: limit.columns))
        let metrics = max(1, FitLimits.clamp(size.metrics, 3, max: limit.metrics))
        let items = FitLimits.clamp(size.items, 0, max: limit.items)
        let top = FitLimits.clamp(size.maxSections, 12, max: limit.sections)
        return ViewThatFits(in: .vertical) {
            cardGrid(top, columns: columns, metrics: metrics, items: items)
            cardGrid(top, columns: columns, metrics: metrics, items: 0)
            cardGrid(top, columns: columns, metrics: max(1, metrics - 1), items: 0)
            cardGrid(top, columns: columns, metrics: 1, items: 0)
            cardGrid(min(top, columns * 2), columns: columns, metrics: 1, items: 0)
        }
    }

    private func cardGrid(_ count: Int, columns: Int, metrics: Int, items: Int) -> some View {
        SectionGrid(sections: Array(sections.prefix(count)), columns: columns, hSpacing: 10, vSpacing: 10) { section in
            Button(intent: OpenSectionIntent(section: section.key)) {
                SectionCard(section: section, accent: accent, maxMetrics: metrics, maxItems: items, opens: true)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tile(accent, attention: section.attentionCount > 0)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Button(intent: CloseSectionIntent()) {
                    HeaderChip(text: "All", symbol: "chevron.left", accent: accent)
                }
                .buttonStyle(.plain)
                SectionLabel(section: section, accent: accent, font: .subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Link(destination: HubStore.widgetLink(section.url)) {
                    HeaderChip(text: "Open", symbol: "arrow.up.right", accent: accent, trailingSymbol: true)
                }
            }
            list.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if family != .systemMedium { Footer(entry: entry, accent: accent) }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var list: some View {
        if section.failed {
            FailedNote(text: section.note)
        } else {
            let metrics = Array(section.metrics.prefix(family == .systemMedium ? 2 : 3))
            if section.items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(metrics: metrics, accent: accent)
                    Label("Nothing waiting here right now.", systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if family == .systemMedium {
                // Too short for figures and a list together; the list is what was clicked for.
                FitDown(from: itemLimit) { n in
                    ItemList(items: section.items, limit: n, accent: accent, moreURL: section.url, compact: true)
                }
            } else {
                FitDown(from: itemLimit) { n in
                    VStack(alignment: .leading, spacing: 8) {
                        StatRow(metrics: metrics, accent: accent)
                        ItemList(items: section.items, limit: n, accent: accent, moreURL: section.url)
                    }
                }
            }
        }
    }
}

struct SectionCard: View {
    let section: PulseSection
    let accent: Color
    var maxMetrics = 6
    var maxItems = 3
    var opens = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            SectionLabel(section: section, accent: accent, opens: opens)
            if section.failed {
                FailedNote(text: section.note)
            } else {
                ForEach(section.metrics.prefix(maxMetrics)) { MetricLine(metric: $0, accent: accent) }
                if maxItems > 0, !section.items.isEmpty {
                    ItemList(items: section.items, limit: maxItems, accent: accent, moreURL: section.url, compact: true)
                        .padding(.top, 3)
                }
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

    private func content(_ section: PulseSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                SectionLabel(section: section, accent: accent,
                             font: family == .systemSmall ? .footnote.weight(.semibold) : .subheadline.weight(.semibold))
                Spacer(minLength: 2)
                if family != .systemSmall {
                    Image(systemName: "arrow.up.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
            detail(section).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            if family == .systemLarge {
                Footer(entry: entry, accent: accent)
            } else if entry.isStale {
                Image(systemName: "wifi.exclamationmark").font(.caption2).foregroundStyle(accent)
            }
        }
        .padding(.vertical, 2)
        .widgetURL(HubStore.widgetLink(section.url))
    }

    @ViewBuilder
    private func detail(_ section: PulseSection) -> some View {
        let sizes = entry.layout.section
        if section.failed {
            FailedNote(text: section.note)
        } else if family == .systemSmall {
            let top = FitLimits.clamp(sizes.small.metrics, 3, max: FitLimits.sectionSmall.metrics)
            let others = section.metrics.filter { $0.key != section.headline?.key }
            FitDown(from: top) { n in
                VStack(alignment: .leading, spacing: 3) {
                    if let lead = section.headline {
                        Text(Fmt.value(lead))
                            .font(.title.weight(.semibold)).monospacedDigit()
                            .minimumScaleFactor(0.5).lineLimit(1)
                            .foregroundStyle(lead.needsAttention ? accent : .primary)
                        Text(lead.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if n > 1 { Divider().overlay(Look.hairline).padding(.vertical, 2) }
                    ForEach(others.prefix(max(0, n - 1))) { MetricLine(metric: $0, accent: accent) }
                }
            }
        } else {
            let large = family == .systemLarge
            let limit = large ? FitLimits.sectionLarge : FitLimits.sectionMedium
            let size = large ? sizes.large : sizes.medium
            let metricCount = max(1, FitLimits.clamp(size.metrics, limit.metrics, max: limit.metrics))
            let metrics = Array(section.metrics.prefix(metricCount))
            let items = FitLimits.clamp(size.items, limit.items, max: limit.items)
            FitDown(from: items, floor: 0) { n in
                VStack(alignment: .leading, spacing: 7) {
                    StatRow(metrics: Array(metrics.prefix(3)), accent: accent)
                    if large, metrics.count > 3 {
                        StatRow(metrics: Array(metrics.dropFirst(3).prefix(3)), accent: accent)
                    }
                    if n > 0, !section.items.isEmpty {
                        ItemList(items: section.items, limit: n, accent: accent, moreURL: section.url, compact: !large)
                    }
                }
            }
        }
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
