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
