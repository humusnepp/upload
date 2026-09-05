import SwiftUI

struct GamePlayerView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var engine = RenPyEngineBridge()
    @State private var showVirtualKeyboard = false
    @State private var showDiagnosticsSheet = false
    @State private var keyboardText = ""
    @State private var hudToastMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // Game viewport with user-selectable display mode
            Group {
                if settings.fillScreen {
                    // Fill screen: covers the entire device display edge-to-edge
                    SDLGameView(engine: engine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                } else {
                    // 16:9 Fit: preserves exact widescreen ratio with letterbox/pillarbox
                    SDLGameView(engine: engine)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                }
            }

            // Top HUD Controls
            HStack(spacing: 16) {
                Button {
                    engine.stop()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.title)
                }

                Spacer()

                // Display Mode Toggle (Fill Screen vs 16:9 Fit)
                Button {
                    withAnimation {
                        settings.fillScreen.toggle()
                        showToast(settings.fillScreen ? "Display: Full Screen (Edge-to-Edge)" : "Display: 16:9 Fit (Letterbox)")
                    }
                } label: {
                    Image(systemName: settings.fillScreen ? "arrow.down.right.and.arrow.up.left.circle.fill" : "arrow.up.left.and.arrow.down.right.circle.fill")
                        .font(.title2)
                }

                // Diagnostics & Logs Button
                Button {
                    showDiagnosticsSheet = true
                } label: {
                    Image(systemName: "terminal.fill")
                        .font(.title2)
                }

                // Virtual Keyboard Button
                Button {
                    showVirtualKeyboard.toggle()
                } label: {
                    Image(systemName: showVirtualKeyboard ? "keyboard.fill" : "keyboard")
                        .font(.title2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .foregroundStyle(.white.opacity(0.85))

            // Temporary HUD Toast for mode changes
            if let hudToastMessage {
                Text(hudToastMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 70)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            // Error Card when engine fails
            if case .failed(let message) = engine.state {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)

                    Text("Couldn't start this game")
                        .font(.headline)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    if !engine.gameFileReport.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Game Files Inspection:")
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text(engine.gameFileReport)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                    }

                    HStack(spacing: 12) {
                        Button("View Engine Logs") {
                            showDiagnosticsSheet = true
                        }
                        .buttonStyle(.bordered)

                        Button("Copy Report") {
                            copyErrorReport(message: message)
                            showToast("Diagnostic report copied to clipboard!")
                        }
                        .buttonStyle(.bordered)

                        Button("Close") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .font(.subheadline)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .safeAreaInset(edge: .bottom) {
            if showVirtualKeyboard {
                VirtualKeyboardBar(text: $keyboardText) { codepoint in
                    engine.sendText(codepoint: codepoint)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showDiagnosticsSheet) {
            DiagnosticsSheet(engine: engine, game: game)
        }
        .onAppear {
            engine.setDisplayScale(settings.screenScale)
            engine.start(game: game)
        }
        .onDisappear {
            engine.stop()
        }
    }

    private func showToast(_ message: String) {
        withAnimation {
            hudToastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                if hudToastMessage == message {
                    hudToastMessage = nil
                }
            }
        }
    }

    private func copyErrorReport(message: String) {
        var report = "=== RenPyPlayer Launch Diagnostic ===\n"
        report += "Game: \(game.name)\n"
        report += "Folder: \(game.folderURL.path)\n"
        report += "Error: \(message)\n\n"
        report += "File Report:\n\(engine.gameFileReport)\n\n"
        report += "Engine Logs:\n"
        report += engine.logs.joined(separator: "\n")
        UIPasteboard.general.string = report
    }
}

/// A detailed scrollable log inspection sheet.
private struct DiagnosticsSheet: View {
    @ObservedObject var engine: RenPyEngineBridge
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Game Details") {
                    LabeledContent("Name", value: game.name)
                    LabeledContent("Folder", value: game.folderName)
                    LabeledContent("Path", value: game.folderURL.path)
                }

                if !engine.gameFileReport.isEmpty {
                    Section("File Structure") {
                        Text(engine.gameFileReport)
                            .font(.caption.monospaced())
                    }
                }

                Section("Engine Event Logs (\(engine.logs.count))") {
                    if engine.logs.isEmpty {
                        Text("No logs recorded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(engine.logs, id: \.self) { log in
                            Text(log)
                                .font(.caption2.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Engine Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(copied ? "Copied!" : "Copy All") {
                        let fullLog = engine.logs.joined(separator: "\n")
                        UIPasteboard.general.string = fullLog
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
