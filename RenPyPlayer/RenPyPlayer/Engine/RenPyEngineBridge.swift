import Foundation

enum RenPyEngineState: Equatable {
    case idle
    case starting
    case running
    case stopped
    case failed(String)
}

enum TouchPhaseForBridge: Int32 {
    case began = 0
    case moved = 1
    case ended = 2
    case cancelled = 3
}

/// Owns the lifecycle of the embedded Ren'Py/Python interpreter.
///
/// IMPORTANT: `renpy_start` / `renpy_pump` / `renpy_stop` / `renpy_send_touch`
/// / `renpy_send_text_codepoint` / `renpy_set_display_scale` are declared in
/// RenPyBridge.h but not implemented anywhere in this Swift project — they
/// must come from linking Ren'Py's official iOS support libraries. This
/// class is the seam where that framework plugs in; everything above it
/// (SwiftUI views, import flow, settings, save paths) works against this
/// class alone and doesn't need to change once the real SDK is linked.
@MainActor
final class RenPyEngineBridge: ObservableObject {
    @Published private(set) var state: RenPyEngineState = .idle

    private var pumpTask: Task<Void, Never>?

    func start(game: Game) {
        guard state == .idle || state == .stopped else { return }
        state = .starting

        let gamePath = game.folderURL.path
        let savesPath = game.savesURL.path
        try? FileManager.default.createDirectory(atPath: savesPath, withIntermediateDirectories: true)

        pumpTask = Task.detached(priority: .userInitiated) { [weak self] in
            let result = gamePath.withCString { gamePathC in
                savesPath.withCString { savesPathC in
                    renpy_start(gamePathC, savesPathC)
                }
            }

            guard result == 0 else {
                await self?.setState(.failed("renpy_start returned \(result)"))
                return
            }

            await self?.setState(.running)

            while (await self?.state) == .running {
                let stillRunning = renpy_pump()
                if !stillRunning { break }
                // Ren'Py/SDL drive their own frame pacing internally; this
                // loop just keeps the host thread alive between pumps and
                // gives external stop requests a chance to take effect.
                try? await Task.sleep(nanoseconds: 1_000_000)
            }

            await self?.setState(.stopped)
        }
    }

    private func setState(_ newState: RenPyEngineState) {
        self.state = newState
    }

    func stop() {
        renpy_stop()
        pumpTask?.cancel()
        pumpTask = nil
        state = .stopped
    }

    func sendTouch(x: Float, y: Float, phase: TouchPhaseForBridge) {
        guard state == .running else { return }
        renpy_send_touch(x, y, phase.rawValue)
    }

    func sendText(codepoint: UInt32) {
        guard state == .running else { return }
        renpy_send_text_codepoint(codepoint)
    }

    func setDisplayScale(_ scale: Float) {
        renpy_set_display_scale(scale)
    }
}
