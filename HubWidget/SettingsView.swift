import SwiftUI
import WidgetKit

@MainActor
final class SettingsModel: ObservableObject {
    @Published var apiKey = APIKeyStore.read() ?? ""
    @Published var apiBase = HubStore.apiBase
    @Published var appBase = HubStore.appBase
    @Published var workspaceId = HubStore.workspaceId ?? ""
    @Published var hidden = HubStore.hiddenSections
    @Published var pulse: Pulse? = HubStore.lastPulse
    @Published var status: String?
    @Published var busy = false

    var hasKey: Bool { !apiKey.trimmingCharacters(in: .whitespaces).isEmpty }

    func saveAndTest() async {
        busy = true
        defer { busy = false }
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("kai_") else {
            status = "An API key starts with kai_. Create one in Profile → Keys."
            return
        }
        let saved = APIKeyStore.save(trimmed)
        guard saved == errSecSuccess else {
            status = "Could not store the key in the Keychain (OSStatus \(saved)). See README → Troubleshooting."
            return
        }
        HubStore.apiBase = apiBase
        HubStore.appBase = appBase
        HubStore.workspaceId = workspaceId.isEmpty ? nil : workspaceId
        HubStore.hiddenSections = hidden

        let result = await PulseClient.refresh()
        pulse = result.pulse
        if let error = result.error {
            status = error
        } else {
            if workspaceId.isEmpty, let ws = result.pulse?.workspace?.id { workspaceId = ws; HubStore.workspaceId = ws }
            status = "Connected. Widgets will refresh within 15 minutes; Refresh now forces it."
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func selectWorkspace(_ id: String) async {
        workspaceId = id
        await saveAndTest()
    }

    func toggle(_ key: String) {
        if hidden.contains(key) { hidden.remove(key) } else { hidden.insert(key) }
        HubStore.hiddenSections = hidden
        WidgetCenter.shared.reloadAllTimelines()
    }

    func forget() {
        APIKeyStore.delete()
        HubStore.lastPulse = nil
        HubStore.workspaceId = nil
        apiKey = ""
        workspaceId = ""
        pulse = nil
        status = "Key removed from this Mac."
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()
    @State private var showAdvanced = false

    var body: some View {
        Form {
            Section {
                SecureField("kai_…", text: $model.apiKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(model.pulse == nil ? "Connect" : "Save & refresh now") {
                        Task { await model.saveAndTest() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.busy || !model.hasKey)
                    if model.busy { ProgressView().controlSize(.small) }
                    Spacer()
                    if model.hasKey { Button("Remove key", role: .destructive) { model.forget() } }
                }
                if let status = model.status {
                    Text(status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } header: {
                Text("API key")
            } footer: {
                Text("Create one in the platform under Profile → Keys → Generate key. It is stored in this Mac's Keychain and only ever sent to the platform.")
            }

            if let pulse = model.pulse {
                if pulse.workspaces.count > 1 {
                    Section("Workspace") {
                        Picker("Workspace", selection: Binding(
                            get: { model.workspaceId.isEmpty ? (pulse.workspace?.id ?? "") : model.workspaceId },
                            set: { id in Task { await model.selectWorkspace(id) } })) {
                            ForEach(pulse.workspaces) { Text($0.name).tag($0.id) }
                        }
                    }
                }

                Section {
                    ForEach(pulse.sections) { section in
                        Toggle(isOn: Binding(get: { !model.hidden.contains(section.key) },
                                             set: { _ in model.toggle(section.key) })) {
                            Label(section.title, systemImage: SectionStyle.symbol(section.key))
                        }
                    }
                    ForEach(pulse.unavailable, id: \.key) { hidden in
                        LabeledContent(hidden.title) {
                            Text(hidden.reason == "not_entitled" ? "Module not in this workspace" : "Not visible to your role")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Sections in the overview widget")
                }

                Section("Preview — \(pulse.workspace?.name ?? "")") {
                    PreviewList(pulse: pulse)
                }
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
                    TextField("API base", text: $model.apiBase)
                    TextField("Web app", text: $model.appBase)
                    Text("Defaults: \(HubStore.defaultAPIBase) and \(HubStore.defaultAppBase).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

struct PreviewList: View {
    let pulse: Pulse

    var body: some View {
        ForEach(pulse.sections) { section in
            VStack(alignment: .leading, spacing: 4) {
                Label(section.title, systemImage: SectionStyle.symbol(section.key)).font(.headline)
                if section.failed {
                    Text(section.note ?? "Could not read this section.").foregroundStyle(.secondary)
                }
                ForEach(section.metrics) { m in
                    HStack {
                        Text(m.label).foregroundStyle(.secondary)
                        Spacer()
                        Text(Fmt.value(m, compact: false)).monospacedDigit()
                            .foregroundStyle(m.needsAttention ? SectionStyle.attention : .primary)
                    }
                }
                if let note = section.note, !section.failed {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
        Text("Updated \(Fmt.ago(pulse.asOf))").font(.caption).foregroundStyle(.secondary)
    }
}
