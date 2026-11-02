import XCTest

final class PulseTests: XCTestCase {
    private func fixture() throws -> Pulse {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "pulse", withExtension: "json"))
        return try JSONDecoder.pulse.decode(Pulse.self, from: Data(contentsOf: url))
    }

    func testDecodesTheServerShape() throws {
        let pulse = try fixture()
        XCTAssertTrue(pulse.ok)
        XCTAssertEqual(pulse.workspace?.name, "Demo workspace")
        XCTAssertEqual(pulse.workspaces.count, 2)
        XCTAssertEqual(pulse.sections.map(\.key), ["finance", "projects", "warehouse"])
        XCTAssertNotNil(pulse.asOf, "Postgres microsecond timestamps must parse")
    }

    func testAttentionComesFromTheServerTone() throws {
        let finance = try XCTUnwrap(try fixture().section("finance"))
        XCTAssertEqual(finance.attentionCount, 1)
        XCTAssertEqual(finance.metrics.first { $0.needsAttention }?.key, "overdue_invoices")
        XCTAssertTrue(finance.metrics[0].isMoney)
    }

    func testAFailedSectionIsUnknownNotZero() throws {
        let warehouse = try XCTUnwrap(try fixture().section("warehouse"))
        XCTAssertTrue(warehouse.failed)
        XCTAssertTrue(warehouse.metrics.isEmpty)
        XCTAssertNotNil(warehouse.note)
    }

    func testUnavailableSectionsCarryTheirReason() throws {
        let reasons = Dictionary(uniqueKeysWithValues: try fixture().unavailable.map { ($0.key, $0.reason) })
        XCTAssertEqual(reasons["hr"], "not_entitled")
        XCTAssertEqual(reasons["tasks"], "no_capability")
    }

    func testItemsWithoutADateDecode() throws {
        let projects = try XCTUnwrap(try fixture().section("projects"))
        XCTAssertEqual(projects.items.count, 2)
        XCTAssertNil(projects.items[1].date)
    }

    func testCacheRoundTrips() throws {
        let pulse = try fixture()
        let data = try JSONEncoder.pulse.encode(pulse)
        let again = try JSONDecoder.pulse.decode(Pulse.self, from: data)
        XCTAssertEqual(again.sections, pulse.sections)
        XCTAssertEqual(again.attention, pulse.attention)
        XCTAssertNotNil(again.asOf)
    }

    func testSampleDataDecodes() {
        XCTAssertNotNil(SamplePulse.value, "the gallery placeholder must decode, or the widget gallery shows nothing")
    }

    func testWidgetLinkCarriesTheQueryString() throws {
        let link = HubStore.widgetLink("/finance?tab=ar")
        XCTAssertEqual(link.scheme, "hubwidget")
        let path = URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "path" }?.value
        XCTAssertEqual(path, "/finance?tab=ar")
    }

    func testMoneyFormatsWithItsCurrency() throws {
        let m = try XCTUnwrap(try fixture().section("finance")?.metrics.first)
        let text = Fmt.value(m, compact: false)
        XCTAssertTrue(text.contains("1,169") || text.contains("1.169") || text.contains("1 169"), text)
    }

    func testPostgresDates() {
        XCTAssertNotNil(PulseDate.parse("2026-11-02T17:50:36.266712+00:00"))
        XCTAssertNotNil(PulseDate.parse("2026-11-02T17:50:36Z"))
        XCTAssertNil(PulseDate.parse("not a date"))
    }

    func testMissingLayoutFallsBackToDefaults() throws {
        let pulse = try fixture()
        XCTAssertEqual(pulse.layout.overview.medium.maxSections, 6)
        XCTAssertNil(pulse.layout.banner)
    }

    func testServerLayoutOrdersSectionsAndToleratesDuplicates() throws {
        var json = try String(contentsOf: XCTUnwrap(Bundle(for: Self.self).url(forResource: "pulse", withExtension: "json")))
        json = json.replacingOccurrences(of: "\"unavailable\": [", with: """
          "layout": {"order": ["warehouse", "projects", "warehouse"], "attention_color": "#FF0000",
                     "banner": {"text": "Month end", "tone": "attention"},
                     "overview": {"medium": {"max_sections": 99}}, "bogus": 1},
          "unavailable": [
        """)
        let pulse = try JSONDecoder.pulse.decode(Pulse.self, from: Data(json.utf8))
        XCTAssertEqual(pulse.orderedSections.map(\.key), ["warehouse", "projects", "finance"])
        XCTAssertEqual(pulse.layout.banner?.text, "Month end")
        XCTAssertEqual(pulse.layout.overview.large.maxSections, 8, "unspecified sizes keep their defaults")
        XCTAssertEqual(FitLimits.clamp(pulse.layout.overview.medium.maxSections, 6, max: FitLimits.overviewMedium.sections), 6,
                       "the server cannot make a widget overflow")
    }

    func testItemsCarryStatusAndMoney() throws {
        let item = try JSONDecoder().decode(PulseItem.self, from: Data(#"{"title":"Q-14","status":"accepted","value":1200.5,"currency":"EUR","tone":"attention"}"#.utf8))
        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(Fmt.status("in_progress"), "In progress")
        XCTAssertEqual(item.value, 1200.5)
    }
}
