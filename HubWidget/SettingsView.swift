import SwiftUI
import WidgetKit
import AppKit

@MainActor
final class SetupModel: ObservableObject {
    @Published var apiKey = ""
    @Published var pulse: Pulse?
    @Published var status: String?
    @Published var busy = false

    func test() async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("kai_") else {
            status = "An API key starts with kai_. Create one in Profile → Keys."
            return
        }
        busy = true
        defer { busy = false }
        do {
            pulse = try await PulseClient(apiKey: key).fetch()
            status = "The key works. Paste the same key into the widget (step 3)."
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            pulse = nil
            status = error.localizedDescription
        }
    }
}

struct SettingsView: View {
    @StateObject private var model = SetupModel()

    var body: some View {
        Form {
            Section {
                Step(n: 1, title: "Create an API key",
                     text: "In the web app open Profile → Keys → Generate key. Bind it to your workspace and copy it — it is shown once.")
                Button("Open Profile → Keys") { NSWorkspace.shared.open(HubStore.appURL("/profile?tab=keys")!) }
            }

            Section {
                Step(n: 2, title: "Check the key (optional)",
                     text: "Paste it here to see exactly what the widget will show. Nothing is stored by this window.")
                HStack {
                    SecureField("kai_…", text: $model.apiKey).textFieldStyle(.roundedBorder)
                    Button("Check") { Task { await model.test() } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.busy || model.apiKey.isEmpty)
                    if model.busy { ProgressView().controlSize(.small) }
                }
                if let status = model.status {
                    Text(status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }

            Section {
                Step(n: 3, title: "Add the widget",
                     text: "Right-click the desktop → Edit Widgets… → search “Hub” → drag Hub overview or Hub section onto the desktop. Then right-click the widget → Edit, and paste the key into API key. Further Hub widgets reuse it.")
            }

            if let pulse = model.pulse {
                Section("Preview — \(pulse.workspace?.name ?? "")") {
                    PreviewList(pulse: pulse)
                }
            }

            Section {
                Text("Keep Hub Widget in Applications: clicking a figure in the widget opens the page in your browser through this app. It does not need to stay open.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

private struct Step: View {
    let n: Int
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(n). \(title)").font(.headline)
            Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
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
        ForEach(pulse.unavailable, id: \.key) { hidden in
            LabeledContent(hidden.title) {
                Text(hidden.reason == "not_entitled" ? "Module not in this workspace" : "Not visible to your role")
                    .foregroundStyle(.secondary)
            }
        }
        Text("Updated \(Fmt.ago(pulse.asOf))").font(.caption).foregroundStyle(.secondary)
    }
}
