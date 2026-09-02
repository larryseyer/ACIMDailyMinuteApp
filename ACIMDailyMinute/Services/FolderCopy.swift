import Foundation

/// A folder the reader supplies, and the one file written into it.
///
/// The third tier of carrying a reader's work: the same backup file the Save
/// button writes, put into a folder they chose once — their own Dropbox, Drive
/// or Syncthing carries it from there. Writing is one direction and the file is
/// a snapshot, which is what makes it safe. Nothing here reads a folder.
///
/// Pure Foundation on purpose: no SwiftData, no SwiftUI, no `UserDefaults`, no
/// `Date()`. `tools/verify_folder_copy.sh` compiles this file and
/// `BackupDocument.swift` and nothing else, and drives it against a real
/// directory — a folder that moves, a folder that is gone, a folder that will
/// not take a write.
enum FolderCopy {
    enum Failure: LocalizedError, Equatable {
        /// The bookmark no longer resolves, or resolves to something that is
        /// not a folder on disk.
        case folderMissing
        /// The folder is there and the write was refused.
        case notWritable(String)
        /// The system would not make a bookmark for the folder at all.
        case notRemembered

        var errorDescription: String? {
            switch self {
            case .folderMissing:
                "The folder can no longer be found. Choose it again."
            case .notWritable(let reason):
                "The copy could not be written. \(reason)"
            case .notRemembered:
                "That folder could not be remembered. Choose it again."
            }
        }
    }

    /// A folder found again from its bookmark.
    struct Resolved {
        let url: URL
        /// Present when the folder had moved and the system rebuilt the
        /// bookmark on the way. The caller stores it in place of the old one so
        /// the next resolution is direct.
        let refreshedBookmark: Data?
    }

    // MARK: - Remembering a folder

    /// A bookmark for `folder`, good across launches.
    ///
    /// On iOS the folder a picker hands over is readable only while its
    /// security scope is open, so the caller opens it around this. On macOS the
    /// scope is baked into the bookmark itself.
    static func bookmark(for folder: URL) throws -> Data {
        do {
            return try folder.bookmarkData(
                options: creationOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw Failure.notRemembered
        }
    }

    static func resolve(_ stored: Data) throws -> Resolved {
        var stale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: stored,
                options: resolutionOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        } catch {
            throw Failure.folderMissing
        }

        guard isDirectory(url) else { throw Failure.folderMissing }
        guard stale else { return Resolved(url: url, refreshedBookmark: nil) }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        // A bookmark that cannot be rebuilt is still a folder that was found;
        // the old data keeps working until it does not.
        let refreshed = try? bookmark(for: url)
        return Resolved(url: url, refreshedBookmark: refreshed)
    }

    // MARK: - The file

    /// Stable, so the folder never fills with dated copies, and named for the
    /// device, so two machines writing into one shared folder never race on a
    /// single name — each file is a whole snapshot of the device that wrote it.
    static func filename(deviceName: String) -> String {
        let cleaned = String(deviceName.map { "/:\\".contains($0) ? "-" : $0 })
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "ACIM Daily Minute backup.json" }
        return "ACIM Daily Minute backup (\(cleaned)).json"
    }

    /// Writes `data` as `filename` inside `folder`, replacing what was there.
    ///
    /// Atomic: the bytes land in a temporary file beside the destination and
    /// take its name in one step, so a sync client watching the folder never
    /// sees a half-written file, and a write that fails leaves the previous
    /// copy exactly as it was.
    static func write(_ data: Data, named filename: String, into folder: URL) throws {
        guard isDirectory(folder) else { throw Failure.folderMissing }

        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        let destination = folder.appendingPathComponent(filename, isDirectory: false)
        do {
            try data.write(to: destination, options: .atomic)
        } catch {
            throw Failure.notWritable(reason(for: error))
        }
    }

    // MARK: - Private

    private static var creationOptions: URL.BookmarkCreationOptions {
        #if os(macOS)
        [.withSecurityScope]
        #else
        []
        #endif
    }

    private static var resolutionOptions: URL.BookmarkResolutionOptions {
        #if os(macOS)
        [.withSecurityScope, .withoutUI]
        #else
        [.withoutUI]
        #endif
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
            && directory.boolValue
    }

    /// The system's own sentence about why, when it has one; a reader on a
    /// full disk or a read-only volume is told which.
    private static func reason(for error: Error) -> String {
        let described = (error as NSError).localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return described.isEmpty ? "The folder refused the file." : described
    }
}
