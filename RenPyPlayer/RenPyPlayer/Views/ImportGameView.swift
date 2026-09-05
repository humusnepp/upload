import SwiftUI
import UniformTypeIdentifiers

struct ImportGameView: View {
    @EnvironmentObject private var library: GameLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var isPickerPresented = false
    @State private var isImporting = false
    @State private var progress: Double = 0
    @State private var progressPhase: String = ""
    @State private var errorMessage: String?
    @State private var urlText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .font(.system(size: 40))
                                .foregroundStyle(AppStyle.accent)
                            Text("Add a Ren'Py Game")
                                .font(.title2.bold())
                            Text("Bring in a game as a zipped project — from your device, iCloud Drive, a network share, or a direct link.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 12) {
                            Label("From Files", systemImage: "folder.fill")
                                .font(.headline)
                            Text("Includes local storage, iCloud Drive, and any SMB share added under Files > Browse > Connect to Server.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                isPickerPresented = true
                            } label: {
                                Text("Choose a .zip File")
                            }
                            .buttonStyle(ProminentGradientButtonStyle(isEnabled: !isImporting))
                            .disabled(isImporting)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("From a URL", systemImage: "link")
                                .font(.headline)
                            TextField("https://example.com/game.zip", text: $urlText)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .disableAutocorrection(true)
                                .padding(12)
                                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Button {
                                importFromURL()
                            } label: {
                                Text("Download & Import")
                            }
                            .buttonStyle(ProminentGradientButtonStyle(isEnabled: !urlText.isEmpty && !isImporting))
                            .disabled(urlText.isEmpty || isImporting)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()

                        if isImporting {
                            VStack(spacing: 10) {
                                HStack {
                                    Text(progressPhase)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                ProgressView(value: progress)
                                    .tint(Color(red: 0.42, green: 0.36, blue: 0.98))
                            }
                            .cardStyle()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if let errorMessage {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Couldn't import that game", systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cardStyle()
                        }
                    }
                    .padding()
                    .animation(.easeInOut(duration: 0.2), value: isImporting)
                }
            }
            .navigationTitle("Import Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [.zip],
                allowsMultipleSelection: false
            ) { result in
                handlePickerResult(result)
            }
        }
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            importZip(at: url, suggestedName: url.deletingPathExtension().lastPathComponent)
        }
    }

    private func importZip(at url: URL, suggestedName: String?) {
        isImporting = true
        errorMessage = nil
        progress = 0
        progressPhase = "Extracting…"

        Task {
            do {
                let (folderName, displayName, thumb) = try await GameImporter.importZip(
                    from: url,
                    displayName: suggestedName
                ) { fraction in
                    Task { @MainActor in
                        self.progress = fraction
                    }
                }

                library.addImportedGame(folderName: folderName, displayName: displayName, thumbnailPath: thumb)
                isImporting = false
                dismiss()
            } catch {
                isImporting = false
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Downloads a network-hosted zip to a temp file, then imports it exactly
    /// like a locally picked file.
    private func importFromURL() {
        guard let remoteURL = URL(string: urlText) else {
            errorMessage = "That doesn't look like a valid URL."
            return
        }
        isImporting = true
        errorMessage = nil
        progress = 0
        progressPhase = "Downloading…"

        Task {
            do {
                let tempURL = try await ProgressDownloader.download(from: remoteURL) { fraction in
                    Task { @MainActor in
                        self.progress = fraction
                    }
                }

                progress = 0
                progressPhase = "Extracting…"

                let suggestedName = remoteURL.deletingPathExtension().lastPathComponent
                let (folderName, displayName, thumb) = try await GameImporter.importZip(
                    from: tempURL,
                    displayName: suggestedName
                ) { fraction in
                    Task { @MainActor in
                        self.progress = fraction
                    }
                }

                library.addImportedGame(folderName: folderName, displayName: displayName, thumbnailPath: thumb)
                isImporting = false
                dismiss()
            } catch {
                isImporting = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
