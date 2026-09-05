import SwiftUI
import UniformTypeIdentifiers

struct ImportGameView: View {
    @EnvironmentObject private var library: GameLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var isPickerPresented = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var urlText: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Import from Files") {
                    Button {
                        isPickerPresented = true
                    } label: {
                        Label("Choose a .zip file", systemImage: "folder")
                    }
                    Text("This includes local storage, iCloud Drive, and any SMB/network share you've added under Files > Browse > Connect to Server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Import from URL") {
                    TextField("https://example.com/game.zip", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .disableAutocorrection(true)
                    Button("Download & Import") {
                        importFromURL()
                    }
                    .disabled(urlText.isEmpty || isImporting)
                }

                if isImporting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Importing…")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Import Game")
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
        Task {
            do {
                let (folderName, displayName) = try GameImporter.importZip(from: url, displayName: suggestedName)
                library.addImportedGame(folderName: folderName, displayName: displayName)
                await MainActor.run {
                    isImporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
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
        Task {
            do {
                let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)
                let suggestedName = remoteURL.deletingPathExtension().lastPathComponent
                let (folderName, displayName) = try GameImporter.importZip(from: tempURL, displayName: suggestedName)
                library.addImportedGame(folderName: folderName, displayName: displayName)
                await MainActor.run {
                    isImporting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
