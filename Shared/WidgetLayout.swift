import Foundation

/// The widget's design, sent by the server (`widget_layouts`). Every field has a default, and every
/// count is clamped to what physically fits that widget size — a layout can restyle the widget but
/// can never make it overflow.
struct WidgetLayout: Codable, Equatable {
    var version = 1
    var attentionColor: String?
    var banner: Banner?
    var order: [String] = []
    var overview = Overview()
    var section = SectionSizes()
    var drilldown = Drilldown()

    enum CodingKeys: String, CodingKey {
        case version, banner, order, overview, section, drilldown
        case attentionColor = "attention_color"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        attentionColor = try? c.decode(String.self, forKey: .attentionColor)
        banner = try? c.decode(Banner.self, forKey: .banner)
        order = (try? c.decode([String].self, forKey: .order)) ?? []
        overview = (try? c.decode(Overview.self, forKey: .overview)) ?? Overview()
        section = (try? c.decode(SectionSizes.self, forKey: .section)) ?? SectionSizes()
        drilldown = (try? c.decode(Drilldown.self, forKey: .drilldown)) ?? Drilldown()
    }

    struct Banner: Codable, Equatable {
        var text: String
        var tone: String?
        var url: String?
    }

    /// One widget size: which style, and how much of each section it shows.
    struct Size: Codable, Equatable {
        var style: String?
        var maxSections: Int?
        var columns: Int?
        var metrics: Int?
        var items: Int?

        enum CodingKeys: String, CodingKey {
            case style, columns, metrics, items
            case maxSections = "max_sections"
        }
    }

    struct Overview: Codable, Equatable {
        var medium = Size(style: "tiles", maxSections: 6, columns: 3)
        var large = Size(style: "rows", maxSections: 6, metrics: 3)
        var extraLarge = Size(style: "cards", maxSections: 12, columns: 3, metrics: 3, items: 0)

        enum CodingKeys: String, CodingKey {
            case medium, large
            case extraLarge = "extra_large"
        }

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Overview()
            medium = (try? c.decode(Size.self, forKey: .medium)) ?? d.medium
            large = (try? c.decode(Size.self, forKey: .large)) ?? d.large
            extraLarge = (try? c.decode(Size.self, forKey: .extraLarge)) ?? d.extraLarge
        }
    }

    struct SectionSizes: Codable, Equatable {
        var small = Size(metrics: 3, items: 0)
        var medium = Size(metrics: 3, items: 2)
        var large = Size(metrics: 6, items: 6)

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = SectionSizes()
            small = (try? c.decode(Size.self, forKey: .small)) ?? d.small
            medium = (try? c.decode(Size.self, forKey: .medium)) ?? d.medium
            large = (try? c.decode(Size.self, forKey: .large)) ?? d.large
        }
    }

    struct Drilldown: Codable, Equatable {
        var items = 6
    }
}

/// The most each widget size can hold without clipping. The server's numbers are capped by these.
enum FitLimits {
    struct Limit { let sections: Int; let columns: Int; let metrics: Int; let items: Int }

    static let overviewMedium = Limit(sections: 6, columns: 3, metrics: 1, items: 0)
    static let overviewLarge = Limit(sections: 6, columns: 1, metrics: 3, items: 0)
    static let overviewExtraLarge = Limit(sections: 12, columns: 3, metrics: 3, items: 2)
    static let sectionSmall = Limit(sections: 1, columns: 1, metrics: 3, items: 0)
    static let sectionMedium = Limit(sections: 1, columns: 1, metrics: 3, items: 2)
    static let sectionLarge = Limit(sections: 1, columns: 1, metrics: 6, items: 6)
    static let drillMedium = 2
    static let drillLarge = 6
    static let drillExtraLarge = 6

    static func clamp(_ value: Int?, _ fallback: Int, max: Int) -> Int {
        Swift.max(0, Swift.min(value ?? fallback, max))
    }
}
