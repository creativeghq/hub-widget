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

struct TileGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    let columns: Int
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8
    @ViewBuilder let cell: (Item) -> Cell

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: hSpacing, verticalSpacing: vSpacing) {
            ForEach(Array(chunked(items, columns).enumerated()), id: \.offset) { _, row in
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

/// A home screen of apps: every area the login can see as an icon over its name, in the server's
/// order. Clicking one zooms the widget into it. Large and extra large keep My tasks and Leads as
/// lists on top.
struct OverviewView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PulseEntry

    private var accent: Color { SectionStyle.accent(entry.layout) }
    private var sections: [PulseSection] { entry.visibleSections }

    var body: some View {
        if entry.pulse == nil {
            MessageView.forMissing(entry)
        } else if let key = entry.drill, let section = entry.pulse?.section(key) {
            DrillView(entry: entry, section: section, accent: accent)
        } else {
            VStack(alignment: .leading, spacing: family == .systemMedium ? 8 : 10) {
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
        default: large
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Hub").font(family == .systemMedium ? .subheadline.weight(.bold) : .headline)
            if family == .systemMedium {
                Text(Fmt.ago(entry.pulse?.asOf)).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            if entry.canAddLead { AddLeadButton(accent: accent) }
            let n = entry.pulse?.attention ?? 0
            if n == 0 {
                Label("All clear", systemImage: "checkmark.circle").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("\(n) need\(n == 1 ? "s" : "") attention")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func appGrid(_ items: [PulseSection], columns: Int, size: CGFloat, spacing: CGFloat = 8) -> some View {
        TileGrid(items: items, columns: columns, hSpacing: 4, vSpacing: spacing) { AppCell(section: $0, size: size) }
    }

    private var medium: some View {
        let size = entry.layout.overview.medium
        let columns = max(4, FitLimits.clamp(size.columns, 6, max: FitLimits.overviewMedium.columns))
        let apps = Array(sections.prefix(FitLimits.clamp(size.maxSections, 12, max: FitLimits.overviewMedium.sections)))
        return ViewThatFits(in: .vertical) {
            appGrid(apps, columns: columns, size: 36, spacing: 6)
            appGrid(apps, columns: columns, size: 32, spacing: 4)
            appGrid(Array(apps.prefix(columns * 2)), columns: columns, size: 30, spacing: 2)
            appGrid(Array(apps.prefix(columns)), columns: columns, size: 30, spacing: 2)
        }
    }

    /// Shown as lists across the top of the large overview, in this order.
    static let listKeys = ["tasks", "crm"]

    private var large: some View {
        let size = entry.layout.overview.large
        let columns = max(3, FitLimits.clamp(size.columns, 4, max: FitLimits.overviewLarge.columns))
        let top = FitLimits.clamp(size.maxSections, 12, max: FitLimits.overviewLarge.sections)
        let lists = Self.listKeys.compactMap { key in sections.first { $0.key == key } }
        let apps = Array(sections.filter { !Self.listKeys.contains($0.key) }.prefix(top))
        return ViewThatFits(in: .vertical) {
            withLists(lists, rows: 3, apps, columns: columns, size: 46)
            withLists(lists, rows: 3, apps, columns: 5, size: 42)
            withLists(lists, rows: 2, apps, columns: 5, size: 40)
            withLists(lists, rows: 1, apps, columns: 5, size: 36)
            appGrid(Array(sections.prefix(top)), columns: 5, size: 36, spacing: 6)
        }
    }

    private var extraLarge: some View {
        let size = entry.layout.overview.extraLarge
        let columns = max(4, FitLimits.clamp(size.columns, 8, max: FitLimits.overviewExtraLarge.columns))
        let top = FitLimits.clamp(size.maxSections, 16, max: FitLimits.overviewExtraLarge.sections)
        let keys = Self.listKeys + ["today"]
        let lists = keys.compactMap { key in sections.first { $0.key == key } }
        let apps = Array(sections.filter { !keys.contains($0.key) }.prefix(top))
        return ViewThatFits(in: .vertical) {
            withLists(lists, rows: 4, apps, columns: columns, size: 50)
            withLists(lists, rows: 3, apps, columns: columns, size: 46)
            withLists(lists, rows: 2, apps, columns: columns, size: 42)
            appGrid(Array(sections.prefix(top)), columns: columns, size: 42, spacing: 6)
        }
    }

    private func withLists(_ lists: [PulseSection], rows: Int, _ apps: [PulseSection], columns: Int,
                           size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !lists.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(lists) { ListPanel(section: $0, accent: accent, rows: rows, workspaceId: entry.workspaceId) }
                }
            }
            appGrid(apps, columns: columns, size: size)
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
                if section.key == "crm", entry.canAddLead { AddLeadButton(accent: accent) }
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
        } else if section.key == "tasks", !section.filters.isEmpty {
            TaskBoard(section: section, filter: entry.taskFilter, accent: accent, workspaceId: entry.workspaceId)
        } else if section.key == "analytics" {
            AnalyticsBoard(section: section, accent: accent, workspaceId: entry.workspaceId)
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
                    ItemList(items: section.items, limit: n, accent: accent, moreURL: section.url, compact: true,
                             workspaceId: entry.workspaceId)
                }
            } else {
                FitDown(from: itemLimit) { n in
                    VStack(alignment: .leading, spacing: 8) {
                        StatRow(metrics: metrics, accent: accent)
                        ItemList(items: section.items, limit: n, accent: accent, moreURL: section.url,
                                 workspaceId: entry.workspaceId)
                    }
                }
            }
        }
    }
}

/// Analytics zoomed in: this month's figures, sales per day for two weeks, and who bought most.
struct AnalyticsBoard: View {
    @Environment(\.widgetFamily) private var family
    let section: PulseSection
    let accent: Color
    var workspaceId: String? = nil

    private var currency: String? { section.metrics.first(where: \.isMoney)?.currency }

    private var chartHeight: CGFloat {
        switch family {
        case .systemMedium: return 52
        case .systemExtraLarge: return 120
        default: return 92
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatRow(metrics: Array(section.metrics.prefix(family == .systemMedium ? 3 : 4)), accent: accent)
            if family != .systemMedium, let note = section.note {
                Text(note).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
            if !section.series.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    if family != .systemMedium {
                        Text("Sales, last 14 days").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    SeriesChart(points: section.series, currency: currency, tint: SectionStyle.tint(section.key))
                        .frame(height: chartHeight)
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .glass()
            }
            if family != .systemMedium {
                Text("Top customers this month").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                if section.items.isEmpty {
                    Label("No sales this month yet.", systemImage: "chart.bar").font(.caption).foregroundStyle(.secondary)
                } else {
                    FitDown(from: family == .systemExtraLarge ? 6 : 4) { n in
                        ItemList(items: section.items, limit: n, accent: accent, moreURL: section.url, compact: true,
                                 workspaceId: workspaceId)
                    }
                }
            }
        }
    }
}

/// My tasks zoomed in: the server's day buckets as filters, the chosen bucket's tasks as cards.
struct TaskBoard: View {
    @Environment(\.widgetFamily) private var family
    let section: PulseSection
    let filter: String?
    let accent: Color
    var workspaceId: String? = nil

    private var shown: [PulseItem] {
        guard let filter else { return section.items }
        return section.items.filter { $0.bucket == filter }
    }

    private var total: Int { section.filters.reduce(0) { $0 + $1.count } }

    /// How many tasks the chosen filter holds on the server, not just how many were sent.
    private var held: Int {
        guard let filter else { return total }
        return section.filters.first { $0.key == filter }?.count ?? shown.count
    }

    private var columns: Int { family == .systemExtraLarge ? 3 : 2 }

    private var capacity: Int {
        switch family {
        case .systemMedium: return 2
        case .systemExtraLarge: return 12
        default: return 6
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                chips(section.filters)
                chips(section.filters.filter { $0.count > 0 || $0.key == filter })
            }
            if shown.isEmpty {
                Label(emptyText, systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
            } else {
                FitDown(from: capacity) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        TileGrid(items: Array(shown.prefix(n)), columns: columns, hSpacing: 6, vSpacing: 6) {
                            TaskCard(item: $0, accent: accent, workspaceId: workspaceId)
                        }
                        if held > min(n, shown.count) {
                            Link(destination: HubStore.widgetLink(section.url)) {
                                HStack(spacing: 4) {
                                    Text("+\(held - min(n, shown.count)) more")
                                    Spacer(minLength: 4)
                                    Text("Open in Hub")
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(accent)
                            }
                        }
                    }
                }
            }
        }
    }

    private func chips(_ filters: [PulseFilter]) -> some View {
        HStack(spacing: 4) {
            FilterChip(label: "All", count: total, filter: "all", selected: filter == nil, accent: accent)
            ForEach(filters) { f in
                FilterChip(label: f.label, count: f.count, filter: f.key, selected: filter == f.key, accent: accent,
                           attention: f.key == "overdue" && f.count > 0)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var emptyText: String {
        switch filter {
        case "overdue": return "Nothing overdue."
        case "today": return "Nothing due today."
        case "tomorrow": return "Nothing due tomorrow."
        case "week": return "Nothing else due this week."
        case "later": return "Nothing due later."
        default: return "No open tasks."
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
                    if section.key == "crm", entry.pulse?.section("crm") != nil { AddLeadButton(accent: accent) }
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
                    if large, !section.series.isEmpty {
                        SeriesChart(points: section.series, currency: metrics.first(where: \.isMoney)?.currency,
                                    tint: SectionStyle.tint(section.key))
                            .frame(height: 80)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .glass()
                    }
                    if n > 0, !section.items.isEmpty {
                        ItemList(items: section.items, limit: n, accent: accent, moreURL: section.url,
                                 compact: !large, workspaceId: entry.workspaceId)
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
