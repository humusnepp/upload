import SwiftUI

@main
struct RenPyPlayerApp: App {
    @StateObject private var library = GameLibrary()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(settings)
        }
    }
}
