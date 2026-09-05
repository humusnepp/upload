import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    HStack {
                        Text("Screen Scale")
                        Slider(value: $settings.screenScale, in: 0.5...2.0, step: 0.05)
                        Text(String(format: "%.2fx", settings.screenScale))
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                }

                Section("Text") {
                    HStack {
                        Text("Text Speed")
                        Slider(value: $settings.textSpeedOverride, in: 0.25...3.0, step: 0.05)
                        Text(String(format: "%.2fx", settings.textSpeedOverride))
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                    Toggle("Skip Mode (auto-advance seen text)", isOn: $settings.skipModeEnabled)
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
