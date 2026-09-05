import SwiftUI
import UIKit

struct GamePlayerView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var engine = RenPyEngineBridge()
    @State private var showVirtualKeyboard = false
    @State private var showDiagnosticsSheet = false
    @State private var keyboardText = ""
    @State private var hudToastMessage: String?
    @State private var hudVisible = true

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────────
            Color.black

            // ── Game surface (always fills the screen; SDL handles its own
            //    aspect-ratio scaling once the real SDK is linked) ─────────
            SDLGameView(engine: engine)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Stub-mode placeholder rendered on top of the SDL surface ──
            // When the real Ren'Py SDK is linked SDL will draw into the
            // underlying UIView and this overlay will be replaced by actual
            // game frames. Until then, show something informative.
            if engine.state == .running {
                StubGameOverlay(game: game)
            }

            // ── Failure card ──────────────────────────────────────────────
            if case .failed(let message) = engine.state {
                errorCard(message: message)
            }

            // ── HUD (tap anywhere to toggle) ──────────────────────────────
            if hudVisible || engine.state != .running {
                VStack {
                    HStack(spacing: 16) {
                        Button {
                            engine.stop()
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.backward.circle.fill")
                                .font(.title)
                        }

                        Spacer()

                        Button { showDiagnosticsSheet = true } label: {
                            Image(systemName: "terminal.fill")
                                .font(.title2)
                        }

                        Button { showVirtualKeyboard.toggle() } label: {
                            Image(systemName: showVirtualKeyboard ? "keyboard.fill" : "keyboard")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .foregroundStyle(.white.opacity(0.85))

                    if let msg = hudToastMessage {
                        Text(msg)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    Spacer()
                }
            }
        }
        // ── This is the critical fix: apply ignoresSafeArea to the whole
        //    ZStack so the game truly fills edge-to-edge on all iPhones ──
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onTapGesture {
            // Tap screen to show/hide HUD while game is running
            if engine.state == .running {
                withAnimation(.easeInOut(duration: 0.2)) { hudVisible.toggle() }
            }
        }
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

    @ViewBuilder
    private func errorCard(message: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)

                Text("Couldn't start this game")
                    .font(.title3.bold())

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if !engine.gameFileReport.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("File Structure Scan")
                            .font(.caption.bold())
                        Text(engine.gameFileReport)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemFill),
                                in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 12) {
                    Button("Logs") { showDiagnosticsSheet = true }
                        .buttonStyle(.bordered)
                    Button("Copy") {
                        copyErrorReport(message: message)
                        showToast("Copied to clipboard")
                    }
                    .buttonStyle(.bordered)
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .font(.subheadline)
            }
            .padding(24)
        }
        .background(.regularMaterial,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func showToast(_ msg: String) {
        withAnimation { hudToastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { if hudToastMessage == msg { hudToastMessage = nil } }
        }
    }

    private func copyErrorReport(message: String) {
        var r = "=== RenPyPlayer Diagnostic ===\n"
        r += "Game: \(game.name)\nPath: \(game.folderURL.path)\n"
        r += "Error: \(message)\n\nFiles:\n\(engine.gameFileReport)\n\nLogs:\n"
        r += engine.logs.joined(separator: "\n")
        UIPasteboard.general.string = r
    }
}

// ── Stub overlay ─────────────────────────────────────────────────────────────
/// Shown over the black SDL surface when the real Ren'Py SDK is not yet linked.
/// Once the SDK is linked and `renpy_start` draws into the SDL view this overlay
/// should be removed (or conditionally hidden via a compile-time flag).
private struct StubGameOverlay: View {
    let game: Game

    var body: some View {
        ZStack {
            // Dim the surface to make the text readable
            Color.black.opacity(0.72)

            VStack(spacing: 20) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.98),
                                     Color(red: 0.65, green: 0.32, blue: 0.86)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))

                Text(game.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Divider()
                    .background(Color.white.opacity(0.2))

                VStack(spacing: 6) {
                    Label("Game files loaded", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline.weight(.semibold))
                    Text("To see actual game frames, link the Ren'Py iOS SDK.\nSee README.md for integration steps.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Text("Engine running in stub mode")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 4)
            }
            .padding(32)
        }
    }
}

// ── Diagnostics sheet ─────────────────────────────────────────────────────────
private struct DiagnosticsSheet: View {
    @ObservedObject var engine: RenPyEngineBridge
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Game") {
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
                Section("Engine Logs (\(engine.logs.count))") {
                    if engine.logs.isEmpty {
                        Text("No logs yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(engine.logs, id: \.self) { log in
                            Text(log).font(.caption2.monospaced())
                        }
                    }
                }
            }
            .navigationTitle("Engine Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(copied ? "Copied!" : "Copy All") {
                        UIPasteboard.general.string = engine.logs.joined(separator: "\n")
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
