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
        XCTAssertEqual(pulse.layout.overview.medium.maxSections, 12)
        XCTAssertEqual(pulse.layout.overview.large.style, "home")
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
        XCTAssertEqual(pulse.layout.overview.large.maxSections, 12, "unspecified sizes keep their defaults")
        XCTAssertEqual(FitLimits.clamp(pulse.layout.overview.medium.maxSections, 6, max: FitLimits.overviewMedium.sections),
                       FitLimits.overviewMedium.sections,
                       "the server cannot make a widget overflow")
    }

    func testItemsCarryStatusAndMoney() throws {
        let item = try JSONDecoder().decode(PulseItem.self, from: Data(#"{"title":"Q-14","status":"accepted","value":1200.5,"currency":"EUR","tone":"attention"}"#.utf8))
        XCTAssertTrue(item.needsAttention)
        XCTAssertEqual(Fmt.status("in_progress"), "In progress")
        XCTAssertEqual(item.value, 1200.5)
    }

    func testNotificationsCarryTheirCategory() throws {
        let json = #"{"notifications":[{"id":"a","type":"warning","title":"Unmatched bank payment","category":"finance"},"#
            + #"{"id":"b","title":"Old server"}],"cursor":null}"#
        let feed = try JSONDecoder().decode(NotificationFeed.self, from: Data(json.utf8))
        XCTAssertEqual(feed.notifications.map(\.category), ["finance", nil])
        XCTAssertEqual(SectionStyle.label("finance"), "Finance")
        XCTAssertEqual(SectionStyle.symbol("jobs"), "briefcase")
        XCTAssertNil(SectionStyle.label(nil), "no category = no subtitle, not a made-up one")
    }

    func testTasksCarryTheServersDayBuckets() throws {
        let json = #"{"key":"tasks","title":"My tasks","status":"ok","url":"/projects/my-tasks","metrics":[],"#
            + #""filters":[{"key":"overdue","label":"Overdue","count":2},{"key":"today","label":"Today","count":0}],"#
            + #""items":[{"title":"Fit doors","date":"2026-10-31","tone":"attention","bucket":"overdue"},"#
            + #"{"title":"Order worktop","date":"2026-11-03","bucket":"today"},{"title":"Later one","date":"2026-11-30","bucket":"later"}]}"#
        let section = try JSONDecoder.pulse.decode(PulseSection.self, from: Data(json.utf8))
        XCTAssertEqual(section.filters.map(\.key), ["overdue", "today"])
        XCTAssertEqual(section.filters.first?.count, 2)
        XCTAssertEqual(section.items.map(\.bucket), ["overdue", "today", "later"])
        XCTAssertTrue(Fmt.due(section.items[0]).hasPrefix("Overdue"))
        XCTAssertEqual(Fmt.due(section.items[1]), "Today")
        let other = try JSONDecoder.pulse.decode(PulseSection.self, from: Data(#"{"key":"crm","filters":null}"#.utf8))
        XCTAssertEqual(other.filters, [], "a section without day buckets decodes with none")
    }

    func testAnalyticsCarriesItsSeriesAndAPercentChange() throws {
        let json = #"{"key":"analytics","title":"Analytics","status":"ok","url":"/finance?tab=reports","#
            + #""metrics":[{"key":"sales_mtd","label":"Sales this month","value":4200,"kind":"money","currency":"EUR","tone":"neutral"},"#
            + #"{"key":"sales_change","label":"vs same days last month","value":-12.5,"kind":"percent","tone":"neutral"}],"#
            + #""series":[{"date":"2026-11-02","value":0},{"date":"2026-11-03","value":942.57}]}"#
        let section = try JSONDecoder.pulse.decode(PulseSection.self, from: Data(json.utf8))
        XCTAssertEqual(section.series.map(\.value), [0, 942.57])
        XCTAssertEqual(Fmt.value(section.metrics[1]), "-12.5%")
        XCTAssertNil(section.badge, "analytics never badges: nothing in it needs acting on")
        XCTAssertEqual(section.shortTitle, "Analytics")
        let other = try JSONDecoder.pulse.decode(PulseSection.self, from: Data(#"{"key":"crm","series":null}"#.utf8))
        XCTAssertEqual(other.series, [])
        XCTAssertEqual(other.shortTitle, "Leads")
    }

    func testABadgeIsTheFirstFigureNeedingAttention() throws {
        let json = #"{"key":"tasks","status":"ok","metrics":[{"key":"overdue","label":"Overdue","value":3,"kind":"count","tone":"attention"}]}"#
        XCTAssertEqual(try JSONDecoder.pulse.decode(PulseSection.self, from: Data(json.utf8)).badge, "3")
        let failed = try JSONDecoder.pulse.decode(PulseSection.self, from: Data(#"{"key":"hr","status":"failed"}"#.utf8))
        XCTAssertEqual(failed.badge, "!", "a section that could not be read says so, never a blank icon")
    }

    func testARefusedWidgetKeyFallsBackToTheAppKey() {
        XCTAssertEqual(PulseClient.candidateKeys(configured: "kai_old", appKey: "kai_new", remembered: "kai_old"),
                       ["kai_old", "kai_new"])
        XCTAssertEqual(PulseClient.candidateKeys(configured: " ", appKey: "kai_new", remembered: nil), ["kai_new"])
        XCTAssertEqual(PulseClient.candidateKeys(configured: nil, appKey: nil, remembered: nil), [])
    }

    func testOnlyATaskWithAnIdCanBeCompleted() throws {
        let task = try JSONDecoder().decode(PulseItem.self, from: Data(#"{"title":"Fit doors","id":"62783b51-6dd3-4864-8cbe-ef9f032b04de","action":"complete_task"}"#.utf8))
        XCTAssertTrue(task.canComplete)
        XCTAssertEqual(task.recordId, "62783b51-6dd3-4864-8cbe-ef9f032b04de")
        let row = try JSONDecoder().decode(PulseItem.self, from: Data(#"{"title":"Q-14","action":"complete_task"}"#.utf8))
        XCTAssertFalse(row.canComplete, "no id = nothing to complete")
    }

    func testLeadDraftSendsOnlyWhatWasTyped() {
        var lead = LeadDraft()
        XCTAssertFalse(lead.isValid)
        lead.name = "Maria Papadopoulou"
        lead.phone = "  "
        lead.value = "1500,50"
        lead.followUp = DateComponents(calendar: .current, year: 2026, month: 11, day: 4, hour: 0, minute: 30).date
        let p = lead.payload
        XCTAssertEqual(p["name"] as? String, "Maria Papadopoulou")
        XCTAssertNil(p["phone"], "a blank field is left out")
        XCTAssertEqual(p["estimated_value"] as? Double, 1500.5)
        XCTAssertEqual(p["follow_up_on"] as? String, "2026-11-04", "the local day, not the UTC one")
        XCTAssertEqual(p["source"] as? String, "phone")
    }

    func testATimestampCursorKeepsItsPlusSign() async throws {
        final class Capture: URLProtocol {
            nonisolated(unsafe) static var url: URL?
            override class func canInit(with request: URLRequest) -> Bool { url = request.url; return true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.cancelled)) }
            override func stopLoading() {}
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [Capture.self]
        let client = PulseClient(apiKey: "kai_test", session: URLSession(configuration: config))
        _ = try? await client.notifications(since: "2026-11-03T05:11:10.552375+00:00")
        let query = try XCTUnwrap(Capture.url?.query(percentEncoded: true))
        XCTAssertTrue(query.contains("%2B00:00") || query.contains("%2B00%3A00"), query)
    }
}
