import WidgetKit
import AppIntents

struct PulseEntry: TimelineEntry {
    let date: Date
    let pulse: Pulse?
    /// Set when the latest fetch failed; `pulse` is then the last good one, shown as stale.
    let error: String?
    let section: SectionKind?
    /// The overview widget is zoomed into this section (an in-widget click), or nil.
    var drill: String? = nil
    /// Overview only: the sections chosen in Edit Widget; empty = all of them.
    var only: [String] = []

    var isStale: Bool { error != nil && pulse != nil }
    var visibleSections: [PulseSection] {
        let all = pulse?.orderedSections ?? []
        return only.isEmpty ? all : all.filter { only.contains($0.key) }
    }
    var workspaceId: String? { pulse?.workspace?.id }
    /// Adding a lead is offered only to a login that can see CRM.
    var canAddLead: Bool { pulse?.section("crm") != nil }
    var layout: WidgetLayout { pulse?.layout ?? WidgetLayout() }

    static func sample(_ section: SectionKind? = nil) -> PulseEntry {
        PulseEntry(date: .now, pulse: SamplePulse.value, error: nil, section: section)
    }
}

enum Refresh {
    /// WidgetKit budgets reloads; 15 minutes is the floor that is honoured reliably.
    static let interval: TimeInterval = 15 * 60

    /// A click inside the widget reloads it; serving a pulse under two minutes old keeps that instant.
    static let clickCache: TimeInterval = 120

    static func load(key: String?, workspace: WorkspaceEntity?, section: SectionKind?, drill: String? = nil) async -> PulseEntry {
        let result = await PulseClient.refresh(key: key, workspaceId: workspace?.id, maxAge: clickCache)
        return PulseEntry(date: .now, pulse: result.pulse, error: result.error, section: section, drill: drill)
    }

    static func load(_ c: OverviewIntent) async -> PulseEntry {
        var entry = await load(key: c.apiKey, workspace: c.workspace, section: nil, drill: DrillState.current)
        entry.only = (c.sections ?? []).map(\.rawValue)
        return entry
    }

    static func timeline(_ entry: PulseEntry) -> Timeline<PulseEntry> {
        Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(interval)))
    }
}

struct OverviewProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PulseEntry { .sample() }

    func snapshot(for configuration: OverviewIntent, in context: Context) async -> PulseEntry {
        context.isPreview ? .sample() : await Refresh.load(configuration)
    }

    func timeline(for configuration: OverviewIntent, in context: Context) async -> Timeline<PulseEntry> {
        Refresh.timeline(await Refresh.load(configuration))
    }
}

struct SectionProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PulseEntry { .sample(.finance) }

    func snapshot(for configuration: SectionIntent, in context: Context) async -> PulseEntry {
        context.isPreview
            ? .sample(configuration.section)
            : await Refresh.load(key: configuration.apiKey, workspace: configuration.workspace, section: configuration.section)
    }

    func timeline(for configuration: SectionIntent, in context: Context) async -> Timeline<PulseEntry> {
        Refresh.timeline(await Refresh.load(key: configuration.apiKey, workspace: configuration.workspace,
                                            section: configuration.section))
    }
}

// MARK: - Configuration ("Edit Widget")

struct OverviewIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Hub overview"
    static var description = IntentDescription("Every section you can see on the platform.")

    @Parameter(title: "API key", description: "Optional. Leave empty to use the key saved in the Hub app Settings.")
    var apiKey: String?

    @Parameter(title: "Workspace", description: "Leave empty to use the key's workspace.")
    var workspace: WorkspaceEntity?

    @Parameter(title: "Sections", description: "Pick the sections to show. Leave empty to show every section you can see.")
    var sections: [SectionKind]?
}

struct SectionIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Hub section"
    static var description = IntentDescription("Choose which part of the platform this widget follows.")

    @Parameter(title: "Section", default: .finance)
    var section: SectionKind

    @Parameter(title: "API key", description: "Optional. Leave empty to use the key saved in the Hub app Settings.")
    var apiKey: String?

    @Parameter(title: "Workspace", description: "Leave empty to use the key's workspace.")
    var workspace: WorkspaceEntity?
}

struct WorkspaceEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workspace"
    static var defaultQuery = WorkspaceQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

/// Lists the workspaces the remembered key can see — available once one widget has a working key.
struct WorkspaceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WorkspaceEntity] {
        let known = (try? await suggestedEntities()) ?? []
        return identifiers.map { id in known.first { $0.id == id } ?? WorkspaceEntity(id: id, name: "Workspace") }
    }

    func suggestedEntities() async throws -> [WorkspaceEntity] {
        guard let key = HubStore.rememberedKey ?? HubStore.appKey else { return [] }
        let pulse = try await PulseClient(apiKey: key).fetch()
        return pulse.workspaces.map { WorkspaceEntity(id: $0.id, name: $0.name) }
    }
}

enum SectionKind: String, AppEnum {
    case today, tasks, projects, finance, quotes, crm, deals, realestate, warehouse, hr, inbox

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Section"
    static var caseDisplayRepresentations: [SectionKind: DisplayRepresentation] = [
        .today: "Today",
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
        case .today: return "Today"
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
