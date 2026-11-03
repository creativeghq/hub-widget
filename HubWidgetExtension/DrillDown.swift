import AppIntents
import WidgetKit

/// Which section the overview widget is zoomed into. Shared by every overview widget on this Mac,
/// and it falls back to the overview by itself after a while so a widget is never left zoomed in.
enum DrillState {
    private static let sectionKey = "drill.section"
    private static let atKey = "drill.at"
    static let timeout: TimeInterval = 10 * 60

    static var current: String? {
        let d = UserDefaults.standard
        guard let section = d.string(forKey: sectionKey),
              Date().timeIntervalSince1970 - d.double(forKey: atKey) < timeout else { return nil }
        return section
    }

    static func set(_ section: String?) {
        let d = UserDefaults.standard
        d.set(section, forKey: sectionKey)
        d.set(Date().timeIntervalSince1970, forKey: atKey)
    }
}

struct OpenSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Open section"
    static var isDiscoverable = false

    @Parameter(title: "Section")
    var section: String

    init() {}
    init(section: String) { self.section = section }

    func perform() async throws -> some IntentResult {
        DrillState.set(section)
        if section == "tasks" { TaskFilterState.set(nil) }
        return .result()
    }
}

/// The day bucket the task board shows; nil = all of them.
enum TaskFilterState {
    private static let key = "tasks.filter"

    static var current: String? { UserDefaults.standard.string(forKey: key) }

    static func set(_ filter: String?) { UserDefaults.standard.set(filter, forKey: key) }
}

struct SetTaskFilterIntent: AppIntent {
    static var title: LocalizedStringResource = "Filter tasks"
    static var isDiscoverable = false

    /// A bucket key, or `all`.
    @Parameter(title: "Filter")
    var filter: String

    init() {}
    init(filter: String) { self.filter = filter }

    func perform() async throws -> some IntentResult {
        TaskFilterState.set(filter == "all" ? nil : filter)
        return .result()
    }
}

struct CloseSectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Back to all sections"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        DrillState.set(nil)
        return .result()
    }
}

/// Ticks a task off from the widget, then reloads so the row disappears.
struct CompleteTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete task"
    static var isDiscoverable = false

    @Parameter(title: "Task")
    var taskId: String

    @Parameter(title: "Workspace")
    var workspaceId: String?

    init() {}
    init(taskId: String, workspaceId: String?) {
        self.taskId = taskId
        self.workspaceId = workspaceId
    }

    func perform() async throws -> some IntentResult {
        guard let key = HubStore.rememberedKey ?? HubStore.appKey else { throw PulseError.noKey }
        try await PulseClient(apiKey: key, workspaceId: workspaceId).completeTask(taskId)
        HubStore.expireFreshPulses()
        return .result()
    }
}
