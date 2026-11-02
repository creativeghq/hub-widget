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
