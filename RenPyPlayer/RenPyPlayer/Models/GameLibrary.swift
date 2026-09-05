import Foundation
import SwiftUI

@MainActor
final class GameLibrary: ObservableObject {
    @Published private(set) var games: [Game] = []

    private let indexFileName = "library_index.json"

    nonisolated static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    nonisolated static var gamesRootURL: URL {
        documentsURL.appendingPathComponent("Games", isDirectory: true)
    }
    nonisolated static var savesRootURL: URL {
        documentsURL.appendingPathComponent("Saves", isDirectory: true)
    }

    init() {
        createDirectoriesIfNeeded()
        loadIndex()
    }

    private func createDirectoriesIfNeeded() {
        let fm = FileManager.default
        for url in [Self.gamesRootURL, Self.savesRootURL] {
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            }
        }
    }

    private var indexURL: URL {
        Self.documentsURL.appendingPathComponent(indexFileName)
    }

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([Game].self, from: data) else {
            games = []
            return
        }
        games = decoded
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(games) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    func addImportedGame(folderName: String, displayName: String) {
        let thumb = locateThumbnail(inFolder: folderName)
        let game = Game(
            id: UUID(),
            name: displayName,
            folderName: folderName,
            importedDate: Date(),
            thumbnailRelativePath: thumb
        )
        games.append(game)
        saveIndex()
    }

    func removeGame(_ game: Game) {
        let fm = FileManager.default
        try? fm.removeItem(at: game.folderURL)
        try? fm.removeItem(at: game.savesURL)
        games.removeAll { $0.id == game.id }
        saveIndex()
    }

    /// Ren'Py projects usually expose an icon at game/gui/window_icon.png.
    /// Some exported zips nest everything under an extra top-level folder,
    /// so we check a couple of likely spots before falling back to a
    /// capped recursive search.
    private func locateThumbnail(inFolder folderName: String) -> String? {
        let base = Self.gamesRootURL.appendingPathComponent(folderName)
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
}
