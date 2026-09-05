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
        GeometryReader { proxy in
            let screenSize = proxy.size
            let screenRatio = screenSize.height > 0 ? (screenSize.width / screenSize.height) : (16.0 / 9.0)

            ZStack {
                // ── Background ────────────────────────────────────────────
                Color.black.ignoresSafeArea()

                // ── Game surface (fills full screen edge-to-edge) ─────────
                SDLGameView(engine: engine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()

                // ── Engine overlay ────────────────────────────────────────
                // Display placeholder overlay only when running in stub mode.
                // When native Ren'Py runtime is linked, SDL draws directly to the screen.
                if engine.state == .running && !engine.isNativeEngine {
                    StubGameOverlay(game: game, screenSize: screenSize, screenRatio: screenRatio)
                }

                // ── Error card on failure ─────────────────────────────────
                if case .failed(let message) = engine.state {
                    errorCard(message: message)
                }

                // ── Clean on-screen HUD (tap screen to toggle) ────────────
                if hudVisible || engine.state != .running {
                    VStack {
                        HStack(spacing: 20) {
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
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
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
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onTapGesture {
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
            // Lock orientation into landscape for widescreen visual novel gaming
            AppDelegate.orientationLock = .landscape
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
                    print("Landscape orientation update: \(error.localizedDescription)")
                }
            }

            engine.setDisplayScale(settings.screenScale)
            engine.start(game: game)
        }
        .onDisappear {
            // Restore all orientations when exiting player
            AppDelegate.orientationLock = .all
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
            }
            engine.stop()
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { hudToastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { if hudToastMessage == msg { hudToastMessage = nil } }
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

                if message.contains("\n") {
                    ScrollView {
                        Text(message)
                            .font(.caption.monospaced())
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(maxHeight: 180)
                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                } else {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

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
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity, alignment: .center)
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
private struct StubGameOverlay: View {
    let game: Game
    let screenSize: CGSize
    let screenRatio: CGFloat

    var body: some View {
        ZStack {
            Color.black.opacity(0.70)

            VStack(spacing: 14) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.42, green: 0.36, blue: 0.98),
                                     Color(red: 0.65, green: 0.32, blue: 0.86)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))

                Text(game.name)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                VStack(spacing: 6) {
                    Label("Game Files Ready (Stub Mode)", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline.weight(.semibold))

                    Text("Active Screen: \(Int(screenSize.width)) × \(Int(screenSize.height)) pt  •  Ratio: \(String(format: "%.2f", screenRatio)):1")
                        .font(.caption.monospaced())
                        .foregroundStyle(.white.opacity(0.85))

                    Text("⚠️ Note: The compiled Ren'Py binary runtime (Python 3 + SDL2) is not linked in this build. The app shell verified your files, but rendering game frames requires the native engine binaries.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 30)
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
