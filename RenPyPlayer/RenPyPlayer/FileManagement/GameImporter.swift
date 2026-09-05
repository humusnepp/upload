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
    static func importZip(from sourceURL: URL, displayName suggestedName: String?) throws -> (folderName: String, displayName: String) {
        let needsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let fm = FileManager.default
        let folderName = "game_\(UUID().uuidString.prefix(8))"
        let destination = GameLibrary.gamesRootURL.appendingPathComponent(folderName, isDirectory: true)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        do {
            try fm.unzipItem(at: sourceURL, to: destination)
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

        let displayName = suggestedName ?? destination.lastPathComponent
        return (folderName, displayName)
    }

    /// A Ren'Py project always has a `game/` directory containing .rpy/.rpyc
    /// scripts. Search a few levels deep since exported zips sometimes nest
    /// the project inside a version-named folder.
    private static func locateGameRoot(under root: URL, maxDepth: Int = 3) -> URL? {
        func hasGameFolder(_ dir: URL) -> Bool {
            FileManager.default.fileExists(atPath: dir.appendingPathComponent("game", isDirectory: true).path)
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
            if fm.fileExists(atPath: target.path) { continue }
            try fm.moveItem(at: item, to: target)
        }
        var dir = gameRoot
        while dir != destination {
            if (try? fm.contentsOfDirectory(atPath: dir.path))?.isEmpty == true {
                try? fm.removeItem(at: dir)
            }
            dir = dir.deletingLastPathComponent()
        }
    }
}
