import SwiftUI
import WidgetKit
import AppKit

@MainActor
final class SetupModel: ObservableObject {
    @Published var apiKey = HubStore.rememberedKey ?? ""
    @Published var pulse: Pulse?
    @Published var status: String?
    @Published var busy = false

    /// Checks the key and keeps it for Mac notifications and for every widget.
    func save(delegate: AppDelegate) async {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("kai_") else {
            status = "An API key starts with kai_. Create one in Profile → Keys."
            return
        }
        busy = true
        defer { busy = false }
        do {
            pulse = try await PulseClient(apiKey: key).fetch()
            HubStore.rememberedKey = key
            HubStore.publishAppKey(key)
            let allowed = await delegate.requestNotificationPermission()
            if !delegate.opensAtLogin { delegate.opensAtLogin = true }
            status = allowed
                ? "Connected. New platform notifications will appear as Mac notifications."
                : "Connected. Mac notifications are off — allow them in System Settings → Notifications → Hub Widget."
            await delegate.poll()
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            pulse = nil
            status = error.localizedDescription
        }
    }

    func forget() {
        HubStore.rememberedKey = nil
        HubStore.publishAppKey(nil)
        HubStore.notificationCursor = nil
        apiKey = ""
        pulse = nil
        status = "Key removed. Widgets keep only a key set in their own Edit Widget."
    }
}

struct SettingsView: View {
    @ObservedObject var delegate: AppDelegate
    @StateObject private var model = SetupModel()
    @State private var notificationsOn = HubStore.notificationsEnabled

    var body: some View {
        Form {
            Section {
                Step(n: 1, title: "Create an API key",
                     text: "In the web app open Profile → Keys → Generate key. Bind it to your workspace and copy it — it is shown once.")
                Button("Open Profile → Keys") { NSWorkspace.shared.open(HubStore.appURL("/profile?tab=keys")!) }
            }

            Section {
                Step(n: 2, title: "Connect this Mac",
                     text: "Paste the key for Mac notifications (quote accepted, task overdue, new conversation…). It stays on this Mac.")
                HStack {
                    SecureField("kai_…", text: $model.apiKey).textFieldStyle(.roundedBorder)
                    Button("Connect") { Task { await model.save(delegate: delegate) } }
                        .keyboardShortcut(.defaultAction)
                        .disabled(model.busy || model.apiKey.isEmpty)
                    if model.busy { ProgressView().controlSize(.small) }
                }
                if let status = model.status {
                    Text(status).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Toggle("Show Mac notifications", isOn: $notificationsOn)
                    .onChange(of: notificationsOn) { _, on in HubStore.notificationsEnabled = on }
                Toggle("Open at login (needed for notifications)", isOn: Binding(
                    get: { delegate.opensAtLogin }, set: { delegate.opensAtLogin = $0 }))
                if !model.apiKey.isEmpty { Button("Remove key", role: .destructive) { model.forget() } }
            }

            Section {
                Step(n: 3, title: "Add the widget",
                     text: "Right-click the desktop → Edit Widgets… → search “Hub” → drag Hub overview or Hub section onto the desktop. Right-click it → Edit, and paste the same key into API key — once; further Hub widgets reuse it.")
                Text("In the overview, click a section to see its list (projects, pending quotes, tasks…); click a row to open it in the browser. ‹ All goes back.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let pulse = model.pulse {
                Section("Preview — \(pulse.workspace?.name ?? "")") {
                    PreviewList(pulse: pulse)
                }
            }

            Section {
                HStack {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Send a test notification") {
                        Task { await delegate.confirm(title: "Test notification", body: "This is how Hub Widget notifications look.", path: "/") }
                    }
                    Button("Check for updates…") { delegate.updater.checkForUpdates(nil) }
                }
            } footer: {
                Text("Updates install automatically. Hub Widget lives in the menu bar; keep it in Applications.")
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
        ForEach(pulse.orderedSections) { section in
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
