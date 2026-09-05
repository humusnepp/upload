import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Screen Scale", systemImage: "arrow.up.left.and.arrow.down.right")
                        Spacer()
                        Text(String(format: "%.2fx", settings.screenScale))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.screenScale, in: 0.5...2.0, step: 0.05)
                        .tint(Color(red: 0.42, green: 0.36, blue: 0.98))
                } header: {
                    Text("Display")
                } footer: {
                    Text("Games automatically expand to fill your display edge-to-edge.")
                }

                Section {
                    HStack {
                        Label("Text Speed", systemImage: "text.word.spacing")
                        Spacer()
                        Text(String(format: "%.2fx", settings.textSpeedOverride))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.textSpeedOverride, in: 0.25...3.0, step: 0.05)
                        .tint(Color(red: 0.42, green: 0.36, blue: 0.98))
                    Toggle(isOn: $settings.skipModeEnabled) {
                        Label("Skip Mode", systemImage: "forward.fill")
                    }
                } header: {
                    Text("Text")
                } footer: {
                    Text("Auto-advances text you've already seen.")
                }

                Section {
                    Text("These overrides are pushed to Ren'Py's preferences at game launch and apply on top of whatever a game's own Preferences screen sets.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
