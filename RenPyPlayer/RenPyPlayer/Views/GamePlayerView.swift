import SwiftUI

struct GamePlayerView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var engine = RenPyEngineBridge()
    @State private var showVirtualKeyboard = false
    @State private var keyboardText = ""

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            SDLGameView(engine: engine)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

            HStack {
                Button {
                    engine.stop()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward.circle.fill")
                        .font(.title)
                }
                Spacer()
                Button {
                    showVirtualKeyboard.toggle()
                } label: {
                    Image(systemName: "keyboard")
                        .font(.title)
                }
            }
            .padding()
            .foregroundStyle(.white.opacity(0.8))

            if case .failed(let message) = engine.state {
                VStack(spacing: 12) {
                    Text("Couldn't start this game")
                        .font(.headline)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Close") { dismiss() }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
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
        .onAppear {
            engine.setDisplayScale(settings.screenScale)
            engine.start(game: game)
        }
        .onDisappear {
            engine.stop()
        }
    }
}
