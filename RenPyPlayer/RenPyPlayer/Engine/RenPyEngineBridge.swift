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
    @Published private(set) var isNativeEngine: Bool = false

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

        isNativeEngine = renpy_is_native()

        let gamePath = game.folderURL.path
        let savesPath = game.savesURL.path

        appendLog("🚀 Initializing Ren'Py Engine for: \(game.name)")
        appendLog("📁 Game root path: \(gamePath)")
        appendLog("💾 Saves directory: \(savesPath)")
        appendLog("⚡ Native Ren'Py binary runtime linked: \(isNativeEngine ? "YES" : "NO (Stub Mode)")")

        // Inspect and report game files
        let report = inspectGameFiles(at: game.folderURL)
        gameFileReport = report
        appendLog(report)

        try? FileManager.default.createDirectory(atPath: savesPath, withIntermediateDirectories: true)

        pumpTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.appendLog("⚡ Calling renpy_start(gamePath, savesPath)...")
            await self?.setState(.running)

            // Poll log output in background so real-time engine stdout/stderr is captured
            let logPoller = Task.detached(priority: .background) { [weak self] in
                var lastReadOffset: UInt64 = 0
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 300_000_000) // every 300ms
                    guard let cPath = renpy_get_log_path(),
                          let logPath = String(validatingUTF8: cPath),
                          !logPath.isEmpty,
                          FileManager.default.fileExists(atPath: logPath) else {
                        continue
                    }

                    if let handle = FileHandle(forReadingAtPath: logPath) {
                        handle.seek(toFileOffset: lastReadOffset)
                        let newData = handle.readDataToEndOfFile()
                        lastReadOffset = handle.offsetInFile
                        try? handle.close()

                        if !newData.isEmpty, let text = String(data: newData, encoding: .utf8) {
                            let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                            for line in lines {
                                await self?.appendLog(line)
                            }
                        }
                    }
                }
            }

            let result = gamePath.withCString { gamePathC in
                savesPath.withCString { savesPathC in
                    renpy_start(gamePathC, savesPathC)
                }
            }

            logPoller.cancel()

            // Read any final buffered log output
            if let cPath = renpy_get_log_path(),
               let logPath = String(validatingUTF8: cPath),
               !logPath.isEmpty,
               let fullLog = try? String(contentsOfFile: logPath, encoding: .utf8) {
                let allLines = fullLog.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                let recentTail = allLines.suffix(20).joined(separator: "\n")

                if result == 0 {
                    await self?.appendLog("✅ renpy_start exited cleanly (code: 0)")
                    await self?.setState(.stopped)
                } else {
                    let errorExplanation: String
                    switch result {
                    case -1:
                        errorExplanation = "renpy_start returned -1: NULL pointer passed for gamePath or savesPath."
                    case -2:
                        errorExplanation = "renpy_start returned -2: Game directory was not found on device filesystem at:\n\(gamePath)"
                    case -3:
                        errorExplanation = "renpy_start returned -3: Missing required 'game/' subfolder in:\n\(gamePath)\nRen'Py visual novels require a 'game/' subfolder containing script files (.rpy / .rpyc) or archives (.rpa)."
                    default:
                        if recentTail.isEmpty {
                            errorExplanation = "renpy_start returned error code \(result)."
                        } else {
                            errorExplanation = "renpy_start returned error code \(result).\n\nEngine Log Output:\n\(recentTail)"
                        }
                    }

                    await self?.appendLog("❌ Failed: \(errorExplanation)")
                    await self?.setState(.failed(errorExplanation))
                }
            } else {
                if result == 0 {
                    await self?.appendLog("✅ renpy_start exited cleanly (code: 0)")
                    await self?.setState(.stopped)
                } else {
                    let errorExplanation = "renpy_start returned error code \(result)."
                    await self?.appendLog("❌ Failed: \(errorExplanation)")
                    await self?.setState(.failed(errorExplanation))
                }
            }
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
