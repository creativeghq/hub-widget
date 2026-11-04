import SwiftUI
import WidgetKit
import AppIntents
import Charts

// MARK: - Building blocks


/// One app on the home grid: icon over its name. Clicking zooms the widget into it.
struct AppCell: View {
    let section: PulseSection
    var size: CGFloat = 44

    var body: some View {
        Button(intent: OpenSectionIntent(section: section.key)) {
            VStack(spacing: 4) {
                AppIcon(key: section.key, size: size, badge: section.badge)
                Text(section.shortTitle)
                    .font(.system(size: size < 40 ? 10 : 11))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SectionLabel: View {
    let section: PulseSection
    let accent: Color
    var font: Font = .footnote.weight(.semibold)
    /// Shows the chevron that says "this opens".
    var opens = false
    var title: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            AppIcon(key: section.key, size: 16)
            Text(title ?? section.title).lineLimit(1)
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
                .glass(tint: m.needsAttention ? accent : nil, radius: 9)
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
    var workspaceId: String? = nil

    var body: some View {
        HStack(spacing: 7) {
            if item.canComplete, let id = item.recordId {
                Button(intent: CompleteTaskIntent(taskId: id, workspaceId: workspaceId)) {
                    Image(systemName: "circle")
                        .font(.body)
                        .foregroundStyle(item.needsAttention ? accent : .secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(item.needsAttention ? accent : Color.secondary.opacity(0.35))
                    .frame(width: 3)
                    .padding(.vertical, 2)
            }
            Link(destination: HubStore.widgetLink(item.url)) { content }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, compact ? 3 : 4)
    }

    private var content: some View {
        HStack(spacing: 7) {
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
        .contentShape(Rectangle())
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
    var workspaceId: String? = nil

    var body: some View {
        let shown = Array(items.prefix(max(0, limit)))
        VStack(spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().overlay(Look.hairline).padding(.leading, 22) }
                ItemRow(item: item, accent: accent, compact: compact, workspaceId: workspaceId)
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

/// A two-line row for a half-width panel: tick box (tasks) or bar, title, then due date or detail.
struct MiniRow: View {
    let item: PulseItem
    let accent: Color
    var workspaceId: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if item.canComplete, let id = item.recordId {
                Button(intent: CompleteTaskIntent(taskId: id, workspaceId: workspaceId)) {
                    Image(systemName: "circle").font(.footnote)
                        .foregroundStyle(item.needsAttention ? accent : .secondary)
                        .frame(width: 15, height: 15).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(item.needsAttention ? accent : Color.secondary.opacity(0.35))
                    .frame(width: 3, height: 24)
            }
            Link(destination: HubStore.widgetLink(item.url)) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title).font(.caption.weight(.medium)).lineLimit(1)
                    Text(detail).font(.caption2).lineLimit(1)
                        .foregroundStyle(item.needsAttention && item.bucket != nil ? accent : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 3)
    }

    private var detail: String {
        item.bucket != nil ? Fmt.due(item) : (item.subtitle ?? Fmt.day(item.date) ?? "")
    }
}

/// A section shown as its list: the header zooms the widget into it, each row opens the record.
struct ListPanel: View {
    let section: PulseSection
    let accent: Color
    let rows: Int
    var workspaceId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button(intent: OpenSectionIntent(section: section.key)) {
                HStack(spacing: 4) {
                    SectionLabel(section: section, accent: accent, font: .caption.weight(.semibold),
                                 title: section.key == "crm" ? "Leads" : nil)
                    Spacer(minLength: 2)
                    if let m = section.headline, !section.failed {
                        Text(Fmt.value(m)).font(.caption.weight(.bold)).monospacedDigit()
                            .foregroundStyle(m.needsAttention ? accent : .secondary)
                    }
                    Image(systemName: "chevron.right").font(.caption2.weight(.bold)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if section.failed {
                FailedNote(text: section.note)
            } else if section.items.isEmpty {
                Text(section.key == "tasks" ? "No open tasks" : "Nothing new").font(.caption2).foregroundStyle(.secondary)
                    .padding(.vertical, 3)
            } else {
                ForEach(Array(section.items.prefix(rows).enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().overlay(Look.hairline) }
                    MiniRow(item: item, accent: accent, workspaceId: workspaceId)
                }
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .tile(accent, attention: section.attentionCount > 0)
    }
}

/// One day filter on the task board, with the server's count.
struct FilterChip: View {
    let label: String
    let count: Int
    let filter: String
    let selected: Bool
    let accent: Color
    var attention = false

    var body: some View {
        Button(intent: SetTaskFilterIntent(filter: filter)) {
            HStack(spacing: 3) {
                Text(label)
                if count > 0 {
                    Text("\(count)").monospacedDigit()
                        .foregroundStyle(attention || selected ? accent : .secondary)
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(selected ? accent : .primary)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .glass(tint: selected ? accent : nil, radius: 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A task as a card: tick box, title, project, due line.
struct TaskCard: View {
    let item: PulseItem
    let accent: Color
    var workspaceId: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if item.canComplete, let id = item.recordId {
                Button(intent: CompleteTaskIntent(taskId: id, workspaceId: workspaceId)) {
                    Image(systemName: "circle").font(.callout)
                        .foregroundStyle(item.needsAttention ? accent : .secondary)
                        .frame(width: 17, height: 17).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Link(destination: HubStore.widgetLink(item.url)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(.caption.weight(.semibold)).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let project = item.subtitle, !project.isEmpty {
                        Text(project).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Label(Fmt.due(item), systemImage: "calendar")
                        .font(.caption2.weight(.medium)).lineLimit(1)
                        .foregroundStyle(item.needsAttention ? accent : .secondary)
                        .padding(.top, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .tile(accent, attention: item.needsAttention)
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
                .glass(radius: 8)
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
        .glass(radius: 8)
    }
}

/// Opens the menu-bar app's form; a widget cannot take typing itself.
struct AddLeadButton: View {
    let accent: Color

    var body: some View {
        Link(destination: HubStore.newLeadLink) {
            HeaderChip(text: "Lead", symbol: "plus", accent: accent)
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

/// Sales per day as bars in the area's colour, money on the trailing axis.
struct SeriesChart: View {
    let points: [PulsePoint]
    let currency: String?
    let tint: Color

    var body: some View {
        Chart(points) { p in
            BarMark(x: .value("Day", p.day, unit: .day), y: .value("Sales", p.value))
                .foregroundStyle(tint.gradient)
                .cornerRadius(3)
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { v in
                AxisGridLine().foregroundStyle(Look.hairline)
                AxisValueLabel {
                    if let d = v.as(Double.self) { Text(Fmt.money(d, currency: currency)).font(.system(size: 9)) }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.system(size: 9))
            }
        }
    }
}
