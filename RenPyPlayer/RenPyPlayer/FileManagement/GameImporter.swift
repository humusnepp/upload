import Foundation
import ZIPFoundation // SPM: https://github.com/weichsel/ZIPFoundation — add via Xcode > Package Dependencies

enum GameImportError: LocalizedError {
    case extractionFailed(Error)
    case noGameDirectoryFound

    var errorDescription: String? {
        switch self {
        case .extractionFailed(let underlying):
            return "Extraction failed: \(underlying.localizedDescription)"
        case .noGameDirectoryFound:
            return "This doesn't look like a Ren'Py project (no game/ folder was found in the zip)."
        }
    }
}

/// Brings a .zip Ren'Py project into the app's sandbox and validates that it
/// actually looks like a Ren'Py game before it's added to the library.
struct GameImporter {

    /// Imports a zip located at `sourceURL` (a security-scoped URL from the
    /// document picker, an SMB share exposed through Files, or a temp file
    /// from a URLSession download) into Documents/Games/<uniqueFolder>/.
    /// - Parameter onProgress: called repeatedly (from a background thread)
    ///   with a value in 0...1 as extraction proceeds. UI code is responsible
    ///   for hopping back to the main actor before touching view state.
    static func importZip(
        from sourceURL: URL,
        displayName suggestedName: String?,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (folderName: String, displayName: String, thumbnailPath: String?) {
        let needsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope { sourceURL.stopAccessingSecurityScopedResource() }
        }

        return try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let folderName = "game_\(UUID().uuidString.prefix(8))"
            let destination = GameLibrary.gamesRootURL.appendingPathComponent(folderName, isDirectory: true)
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)

            let progress = Progress()
            var observation: NSKeyValueObservation?
            if let onProgress {
                observation = progress.observe(\.fractionCompleted, options: [.new]) { prog, _ in
                    onProgress(prog.fractionCompleted)
                }
            }
            defer { observation?.invalidate() }

            do {
                try fm.unzipItem(at: sourceURL, to: destination, progress: progress)
            } catch {
                try? fm.removeItem(at: destination)
                throw GameImportError.extractionFailed(error)
            }

            guard let gameRoot = locateGameRoot(under: destination) else {
                try? fm.removeItem(at: destination)
                throw GameImportError.noGameDirectoryFound
            }

            if gameRoot != destination {
                try flatten(gameRoot: gameRoot, into: destination)
            }

            let thumb = locateThumbnail(inFolder: destination)
            let displayName = suggestedName ?? destination.lastPathComponent
            return (folderName, displayName, thumb)
        }.value
    }

    private static func locateThumbnail(inFolder base: URL) -> String? {
        let candidates = [
            "game/gui/window_icon.png",
            "gui/window_icon.png",
            "game/gui/game_icon.png"
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: base.appendingPathComponent(candidate).path) {
                return candidate
            }
        }
        if let enumerator = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) {
            var visited = 0
            for case let fileURL as URL in enumerator {
                visited += 1
                if visited > 5000 { break }
                if fileURL.lastPathComponent == "window_icon.png" {
                    return fileURL.path.replacingOccurrences(of: base.path + "/", with: "")
                }
            }
        }
        return nil
    }

    /// A Ren'Py project always has a `game/` directory containing .rpy/.rpyc
    /// scripts. Search a few levels deep since exported zips sometimes nest
    /// the project inside a version-named folder.
    private static func locateGameRoot(under root: URL, maxDepth: Int = 3) -> URL? {
        func hasGameFolder(_ dir: URL) -> Bool {
            let fm = FileManager.default
            let pathLower = dir.appendingPathComponent("game", isDirectory: true).path
            let pathUpper = dir.appendingPathComponent("Game", isDirectory: true).path
            return fm.fileExists(atPath: pathLower) || fm.fileExists(atPath: pathUpper)
        }
        if hasGameFolder(root) { return root }

        guard maxDepth > 0,
              let contents = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return nil
        }
        for item in contents {
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                if let found = locateGameRoot(under: item, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        return nil
    }

    private static func flatten(gameRoot: URL, into destination: URL) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: gameRoot, includingPropertiesForKeys: nil)
        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            if fm.fileExists(atPath: target.path) {
                try? fm.removeItem(at: target)
            }
            try fm.moveItem(at: item, to: target)
        }

        // Clean up the now-empty source hierarchy inside destination
        let destPath = destination.standardizedFileURL.path
        var current = gameRoot.standardizedFileURL
        while current.path != destPath && current.path.hasPrefix(destPath) && current.path != "/" {
            let parent = current.deletingLastPathComponent()
            if parent.path == destPath {
                try? fm.removeItem(at: current)
                break
            }
            current = parent
        }
    }
}
