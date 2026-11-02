import WidgetKit
import AppIntents

struct PulseEntry: TimelineEntry {
    let date: Date
    let pulse: Pulse?
    /// Set when the latest fetch failed; `pulse` is then the last good one, shown as stale.
    let error: String?
    let section: SectionKind?
    let hidden: Set<String>

    var isStale: Bool { error != nil && pulse != nil }

    var visibleSections: [PulseSection] {
        (pulse?.sections ?? []).filter { !hidden.contains($0.key) }
    }
}

enum Refresh {
    /// WidgetKit budgets reloads; 15 minutes is the floor that is honoured reliably.
    static let interval: TimeInterval = 15 * 60
    static func next(after date: Date = .now) -> Date { date.addingTimeInterval(interval) }
}

/// The all-sections widget.
struct OverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, pulse: SamplePulse.value, error: nil, section: nil, hidden: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> Void) {
        if context.isPreview {
            completion(PulseEntry(date: .now, pulse: HubStore.lastPulse ?? SamplePulse.value, error: nil, section: nil, hidden: []))
            return
        }
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseEntry>) -> Void) {
        Task {
            let entry = await load()
            completion(Timeline(entries: [entry], policy: .after(Refresh.next())))
        }
    }

    private func load() async -> PulseEntry {
        let result = await PulseClient.refresh()
        return PulseEntry(date: .now, pulse: result.pulse, error: result.error, section: nil, hidden: HubStore.hiddenSections)
    }
}

/// The single-section widget, configured from "Edit Widget".
struct SectionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(date: .now, pulse: SamplePulse.value, error: nil, section: .finance, hidden: [])
    }

    func snapshot(for configuration: SectionIntent, in context: Context) async -> PulseEntry {
        if context.isPreview {
            return PulseEntry(date: .now, pulse: HubStore.lastPulse ?? SamplePulse.value, error: nil,
                              section: configuration.section, hidden: [])
        }
        return await load(configuration)
    }

    func timeline(for configuration: SectionIntent, in context: Context) async -> Timeline<PulseEntry> {
        Timeline(entries: [await load(configuration)], policy: .after(Refresh.next()))
    }

    private func load(_ configuration: SectionIntent) async -> PulseEntry {
        let result = await PulseClient.refresh()
        return PulseEntry(date: .now, pulse: result.pulse, error: result.error, section: configuration.section, hidden: [])
    }
}

struct SectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Section"
    static var description = IntentDescription("Choose which part of the platform this widget follows.")

    @Parameter(title: "Section", default: .finance)
    var section: SectionKind
}

enum SectionKind: String, AppEnum {
    case tasks, projects, finance, quotes, crm, deals, realestate, warehouse, hr, inbox

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Section"
    static var caseDisplayRepresentations: [SectionKind: DisplayRepresentation] = [
        .tasks: "My tasks",
        .projects: "Projects",
        .finance: "Finance",
        .quotes: "Quotes",
        .crm: "CRM",
        .deals: "Deals",
        .realestate: "Real estate",
        .warehouse: "Warehouse",
        .hr: "HR",
        .inbox: "Inbox",
    ]

    var title: String {
        switch self {
        case .tasks: return "My tasks"
        case .projects: return "Projects"
        case .finance: return "Finance"
        case .quotes: return "Quotes"
        case .crm: return "CRM"
        case .deals: return "Deals"
        case .realestate: return "Real estate"
        case .warehouse: return "Warehouse"
        case .hr: return "HR"
        case .inbox: return "Inbox"
        }
    }
}
