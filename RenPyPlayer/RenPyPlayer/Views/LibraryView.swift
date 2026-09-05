import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: GameLibrary
    @State private var showImporter = false
    @State private var showSettings = false
    @State private var gameToLaunch: Game?

    // .adaptive + a card that sizes itself by aspect ratio (rather than a
    // fixed height) is what keeps the grid looking right from an iPhone SE
    // up through a Pro Max: the column count changes with screen width, but
    // every card keeps the same proportions instead of stretching or
    // cropping oddly on wider phones.
    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 300), spacing: 18)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                Group {
                    if library.games.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 22) {
                                ForEach(library.games) { game in
                                    GameCell(game: game)
                                        .onTapGesture { gameToLaunch = game }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                withAnimation { library.removeGame(game) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("My Games")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showImporter = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppStyle.accent.opacity(0.15))
                    .frame(width: 110, height: 110)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(AppStyle.accent)
            }
            Text("No Games Yet")
                .font(.title3.bold())
            Text("Import a Ren'Py .zip to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showImporter = true
            } label: {
                Label("Import a Game", systemImage: "plus")
                    .padding(.horizontal, 8)
            }
            .buttonStyle(ProminentGradientButtonStyle())
            .frame(maxWidth: 220)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct GameCell: View {
    let game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppStyle.accent.opacity(0.18))

                if let thumbURL = game.thumbnailURL,
                   let uiImage = UIImage(contentsOfFile: thumbURL.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AppStyle.accent)
                        Text("16:9")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // 16:9 widescreen aspect ratio matching standard Ren'Py game resolutions (1920x1080 / 1280x720)
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

            Text(game.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
