import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: GameLibrary
    @State private var showImporter = false
    @State private var showSettings = false
    @State private var gameToLaunch: Game?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if library.games.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Games Yet")
                            .font(.headline)
                        Text("Import a Ren'Py .zip to get started.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(library.games) { game in
                                GameCell(game: game)
                                    .onTapGesture { gameToLaunch = game }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            library.removeGame(game)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("My Games")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showImporter = true } label: {
                        Label("Import Game", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showImporter) {
                ImportGameView().environmentObject(library)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(item: $gameToLaunch) { game in
                GamePlayerView(game: game)
            }
        }
    }
}

private struct GameCell: View {
    let game: Game

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.thinMaterial)
                if let thumbURL = game.thumbnailURL,
                   let uiImage = UIImage(contentsOfFile: thumbURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 140)

            Text(game.name)
                .font(.subheadline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }
}
