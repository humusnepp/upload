import Foundation

/// A thin wrapper around a URLSession download task that reports byte-level
/// progress. `URLSession.shared.download(from:)`'s async/await form has no
/// progress callback, so this uses the delegate-based API instead.
final class ProgressDownloader: NSObject, @unchecked Sendable, URLSessionDownloadDelegate {
    private let onProgress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?

    private init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    /// Downloads `url` to a temporary file, invoking `onProgress` with a
    /// value in 0...1 as bytes arrive. The returned URL is only valid until
    /// the caller returns control to the run loop, per URLSession's contract
    /// for download tasks — move it before doing anything async.
    static func download(from url: URL, onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let downloader = ProgressDownloader(onProgress: onProgress)
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: downloader, delegateQueue: nil)
        downloader.session = session

        return try await withCheckedThrowingContinuation { continuation in
            downloader.continuation = continuation
            let task = session.downloadTask(with: url)
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(min(max(fraction, 0), 1))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move immediately: the file at `location` is deleted as soon as this
        // delegate method returns.
        do {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("zip")
            try FileManager.default.moveItem(at: location, to: tempURL)
            continuation?.resume(returning: tempURL)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            session.finishTasksAndInvalidate()
        }
    }
}
