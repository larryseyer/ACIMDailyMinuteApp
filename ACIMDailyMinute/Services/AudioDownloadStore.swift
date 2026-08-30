import Foundation

/// Downloaded readings, kept in Application Support so they survive relaunches
/// and are excluded from the photo-style backup churn of Documents.
///
/// MP3 only, by decision. The reader keeps what they download; nothing here
/// depends on the host still existing tomorrow.
enum AudioDownloadStore {
    enum DownloadError: Error { case badURL, writeFailed }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Readings", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Episode ids come from the feed's own GUIDs and can contain path
    /// separators, so they are not safe as filenames as-is.
    private static func filename(for episodeID: String) -> String {
        let safe = episodeID.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? Character($0) : "-"
        }
        return String(safe) + ".mp3"
    }

    static func localURL(for episodeID: String) -> URL? {
        let url = directory.appendingPathComponent(filename(for: episodeID))
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func isDownloaded(_ episodeID: String) -> Bool {
        localURL(for: episodeID) != nil
    }

    @discardableResult
    static func download(episodeID: String, remoteURL: String) async throws -> URL {
        guard let source = URL(string: AudioManager.resolve(remoteURL)) else {
            throw DownloadError.badURL
        }
        let (temp, _) = try await URLSession.shared.download(from: source)
        let destination = directory.appendingPathComponent(filename(for: episodeID))
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: temp, to: destination)
        } catch {
            throw DownloadError.writeFailed
        }
        return destination
    }

    static func delete(_ episodeID: String) {
        guard let url = localURL(for: episodeID) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
