import SwiftUI
import WidgetKit

@MainActor
final class QuickLeadModel: ObservableObject {
    @Published var draft = LeadDraft()
    @Published var hasFollowUp = false
    @Published var followUp = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @Published var busy = false
    @Published var error: String?

    /// Saves through the platform, then confirms with a Mac notification that opens the Leads tab.
    func save(delegate: AppDelegate, close: () -> Void) async {
        guard let key = HubStore.rememberedKey else {
            error = "Connect this Mac first: Settings… → paste your kai_ key."
            return
        }
        var lead = draft
        lead.followUp = hasFollowUp ? followUp : nil
        busy = true
        defer { busy = false }
        do {
            let path = try await PulseClient(apiKey: key).createLead(lead)
            await delegate.confirm(title: "Lead added", body: lead.name, path: path)
            WidgetCenter.shared.reloadAllTimelines()
            draft = LeadDraft()
            hasFollowUp = false
            error = nil
            close()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct QuickLeadView: View {
    @ObservedObject var delegate: AppDelegate
    @StateObject private var model = QuickLeadModel()
    let close: () -> Void
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section {
                    TextField("Name", text: $model.draft.name, prompt: Text("Required"))
                        .focused($nameFocused)
                    TextField("Phone", text: $model.draft.phone)
                    TextField("Email", text: $model.draft.email)
                    TextField("Company (optional)", text: $model.draft.company)
                }
                Section {
                    TextField("What they want (optional)", text: $model.draft.request, axis: .vertical)
                        .lineLimit(3...6)
                    Picker("Came in by", selection: $model.draft.source) {
                        ForEach(LeadDraft.sources, id: \.key) { Text($0.label).tag($0.key) }
                    }
                    Toggle("Follow up", isOn: $model.hasFollowUp)
                    if model.hasFollowUp {
                        DatePicker("On", selection: $model.followUp, displayedComponents: .date)
                    }
                    TextField("Estimated value (optional)", text: $model.draft.value)
                }
            }
            .formStyle(.grouped)

            if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.red)
                    .padding(.horizontal, 20)
            }

            HStack {
                Button("Open Leads") { NSWorkspace.shared.open(HubStore.appURL("/crm?tab=leads")!) }
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button("Cancel", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction)
                Button("Add lead") { Task { await model.save(delegate: delegate, close: close) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.busy || !model.draft.isValid)
            }
            .padding(16)
        }
        .frame(width: 440)
        .onAppear { nameFocused = true }
    }
}
