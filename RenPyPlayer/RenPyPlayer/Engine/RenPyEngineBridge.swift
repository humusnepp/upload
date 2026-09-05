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
@MainActor
final class RenPyEngineBridge: ObservableObject {
    @Published private(set) var state: RenPyEngineState = .idle
    @Published private(set) var logs: [String] = []
    @Published private(set) var gameFileReport: String = ""

    private var pumpTask: Task<Void, Never>?

    func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)"
        logs.append(entry)
        print(entry)
    }

    func start(game: Game) {
        guard state == .idle || state == .stopped else { return }
        state = .starting
        logs.removeAll()

        let gamePath = game.folderURL.path
        let savesPath = game.savesURL.path

        appendLog("🚀 Initializing Ren'Py Engine for: \(game.name)")
        appendLog("📁 Game root path: \(gamePath)")
        appendLog("💾 Saves directory: \(savesPath)")

        // Inspect and report game files
        let report = inspectGameFiles(at: game.folderURL)
        gameFileReport = report
        appendLog(report)

        try? FileManager.default.createDirectory(atPath: savesPath, withIntermediateDirectories: true)

        pumpTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.appendLog("⚡ Calling renpy_start(gamePath, savesPath)...")

            let result = gamePath.withCString { gamePathC in
                savesPath.withCString { savesPathC in
                    renpy_start(gamePathC, savesPathC)
                }
            }

            guard result == 0 else {
                let errorExplanation: String
                switch result {
                case -1:
                    errorExplanation = "renpy_start returned -1: NULL pointer passed for gamePath or savesPath."
                case -2:
                    errorExplanation = "renpy_start returned -2: Game directory was not found on device filesystem at:\n\(gamePath)"
                case -3:
                    errorExplanation = "renpy_start returned -3: Missing required 'game/' subfolder in:\n\(gamePath)\nRen'Py visual novels require a 'game/' subfolder containing script files (.rpy / .rpyc) or archives (.rpa)."
                default:
                    errorExplanation = "renpy_start returned error code \(result)."
                }

                await self?.appendLog("❌ Failed: \(errorExplanation)")
                await self?.setState(.failed(errorExplanation))
                return
            }

            await self?.appendLog("✅ renpy_start succeeded (code: 0)")
            await self?.appendLog("🎮 Engine state -> running. Beginning pump loop...")
            await self?.setState(.running)

            var pumpCount: UInt64 = 0
            while (await self?.state) == .running {
                let stillRunning = renpy_pump()
                if !stillRunning {
                    await self?.appendLog("⏹️ renpy_pump returned false. Game exited.")
                    break
                }
                pumpCount += 1
                if pumpCount == 60 {
                    await self?.appendLog("🔄 Engine loop healthy (first 60 frames pumped).")
                }
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps pump cadence
            }

            await self?.setState(.stopped)
            await self?.appendLog("🛑 Engine stopped.")
        }
    }

    private func inspectGameFiles(at folder: URL) -> String {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else {
            return "❌ Game directory does not exist on disk!"
        }

        var lines: [String] = []
        let gameSubdir = folder.appendingPathComponent("game", isDirectory: true)
        let hasGameSubdir = fm.fileExists(atPath: gameSubdir.path)

        lines.append("Subdirectory 'game/': \(hasGameSubdir ? "✅ Found" : "❌ Missing")")

        if let contents = try? fm.contentsOfDirectory(atPath: hasGameSubdir ? gameSubdir.path : folder.path) {
            let rpys = contents.filter { $0.hasSuffix(".rpy") }
            let rpycs = contents.filter { $0.hasSuffix(".rpyc") }
            let rpas = contents.filter { $0.hasSuffix(".rpa") }

            lines.append("Files detected: \(contents.count) total")
            if !rpys.isEmpty { lines.append("Scripts (.rpy): \(rpys.prefix(6).joined(separator: ", "))\(rpys.count > 6 ? " ... (\(rpys.count) total)" : "")") }
            if !rpycs.isEmpty { lines.append("Compiled (.rpyc): \(rpycs.prefix(6).joined(separator: ", "))\(rpycs.count > 6 ? " ... (\(rpycs.count) total)" : "")") }
            if !rpas.isEmpty { lines.append("Archives (.rpa): \(rpas.joined(separator: ", "))") }
        }

        return lines.joined(separator: "\n")
    }

    private func setState(_ newState: RenPyEngineState) {
        self.state = newState
    }

    func stop() {
        appendLog("🛑 Stop requested by user.")
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
