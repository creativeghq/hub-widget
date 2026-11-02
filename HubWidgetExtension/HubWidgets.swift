import SwiftUI
import WidgetKit

@main
struct HubWidgetBundle: WidgetBundle {
    var body: some Widget {
        OverviewWidget()
        SectionWidget()
    }
}

struct OverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HubOverview", provider: OverviewProvider()) { entry in
            OverviewView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hub overview")
        .description("Every section you can see — what needs attention first.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct SectionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HubSection", intent: SectionIntent.self, provider: SectionProvider()) { entry in
            SectionView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hub section")
        .description("One section — Finance, Projects, Real estate and more.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview("Overview", as: .systemLarge) {
    OverviewWidget()
} timeline: {
    PulseEntry(date: .now, pulse: SamplePulse.value, error: nil, section: nil, hidden: [])
}

#Preview("Finance", as: .systemSmall) {
    SectionWidget()
} timeline: {
    PulseEntry(date: .now, pulse: SamplePulse.value, error: nil, section: .finance, hidden: [])
}
