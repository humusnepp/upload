import Foundation

struct Game: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var folderName: String        // Directory name inside Documents/Games/
    var importedDate: Date
    var thumbnailRelativePath: String?  // relative path to window_icon.png inside the game folder, if found

    var folderURL: URL {
        GameLibrary.gamesRootURL.appendingPathComponent(folderName, isDirectory: true)
    }

    var savesURL: URL {
        GameLibrary.savesRootURL.appendingPathComponent(folderName, isDirectory: true)
    }

    var thumbnailURL: URL? {
        guard let relPath = thumbnailRelativePath else { return nil }
        return folderURL.appendingPathComponent(relPath)
    }
}
