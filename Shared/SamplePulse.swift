import Foundation

/// Placeholder data for the widget gallery and SwiftUI previews only — never shown as real figures.
enum SamplePulse {
    static let json = """
    {"ok":true,"workspace":{"id":"00000000-0000-0000-0000-000000000000","name":"Your workspace"},
     "as_of":"2026-11-02T09:00:00+00:00","attention":4,
     "sections":[
      {"key":"tasks","title":"My tasks","status":"ok","url":"/projects/my-tasks","items":[],"metrics":[
        {"key":"overdue","label":"Overdue","value":2,"kind":"count","tone":"attention"},
        {"key":"due_soon","label":"Due in 7 days","value":5,"kind":"count","tone":"neutral"},
        {"key":"open","label":"Open","value":14,"kind":"count","tone":"neutral"}]},
      {"key":"projects","title":"Projects","status":"ok","url":"/projects","metrics":[
        {"key":"active","label":"Active","value":6,"kind":"count","tone":"neutral"},
        {"key":"total","label":"All projects","value":21,"kind":"count","tone":"neutral"}],
       "items":[{"title":"Kifisia kitchen","subtitle":"in_progress","date":"2026-11-20"},
                {"title":"Glyfada villa","subtitle":"planning","date":"2026-12-04"}]},
      {"key":"finance","title":"Finance","status":"ok","url":"/finance?tab=ar","items":[],"metrics":[
        {"key":"receivables","label":"Owed to you","value":48250,"kind":"money","currency":"EUR","tone":"neutral"},
        {"key":"overdue_invoices","label":"Overdue invoices","value":3,"kind":"count","tone":"attention"},
        {"key":"mydata_failed","label":"myDATA not accepted","value":0,"kind":"count","tone":"neutral"},
        {"key":"supplier_docs_new","label":"Supplier documents to file","value":12,"kind":"count","tone":"neutral"}]},
      {"key":"deals","title":"Deals","status":"ok","url":"/crm?tab=pipeline","items":[],"metrics":[
        {"key":"open","label":"Open deals","value":9,"kind":"count","tone":"neutral"},
        {"key":"weighted","label":"Weighted pipeline","value":126000,"kind":"money","currency":"EUR","tone":"neutral"},
        {"key":"closing_7d","label":"Closing in 7 days","value":2,"kind":"count","tone":"neutral"}]},
      {"key":"realestate","title":"Real estate","status":"ok","url":"/properties","items":[],"metrics":[
        {"key":"active_listings","label":"Active listings","value":17,"kind":"count","tone":"neutral"},
        {"key":"viewings_7d","label":"Viewings in 7 days","value":4,"kind":"count","tone":"neutral"},
        {"key":"new_inquiries","label":"New enquiries","value":1,"kind":"count","tone":"attention"}]},
      {"key":"warehouse","title":"Warehouse","status":"ok","url":"/warehouse","items":[],"metrics":[
        {"key":"low_stock","label":"Below reorder point","value":0,"kind":"count","tone":"neutral"},
        {"key":"pending_receipt","label":"Lines to receive","value":8,"kind":"count","tone":"neutral"}]},
      {"key":"inbox","title":"Inbox","status":"ok","url":"/inbox","items":[],"metrics":[
        {"key":"open_threads","label":"Open conversations","value":3,"kind":"count","tone":"attention"}]}
     ],
     "unavailable":[],"workspaces":[]}
    """

    static let value: Pulse? = try? JSONDecoder.pulse.decode(Pulse.self, from: Data(json.utf8))
}
