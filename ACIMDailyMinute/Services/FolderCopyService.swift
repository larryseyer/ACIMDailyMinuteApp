import Foundation
import SwiftData
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Keeps the reader's backup file current in a folder they chose.
///
/// The one place that remembers the folder, decides when to write, and builds
/// the document to write. `FolderCopy` does the file system work and is pure;
/// this is the thin, impure shell around it — it holds `UserDefaults`, a
/// `ModelContext` and the clock, and nothing that could be checked without them.
///
/// ⛔ It writes and never reads. A folder two machines both write into is
/// exactly where a second, automatic merge would lose a reader's words, so
/// restoring stays something they ask for on the Backup & Restore screen.
@MainActor
enum FolderCopyService {
    /// Device-local keys, in `UserDefaults.standard` with every other reader
    /// setting. None of them travels in a backup: a bookmark means nothing on
    /// another machine, and where a device writes is consent given per device.
    enum Key {
        static let bookmark = "folderCopyBookmark"
        static let folderName = "folderCopyFolderName"
        /// `timeIntervalSinceReferenceDate`, so `@AppStorage` can watch it.
        static let lastWrittenAt = "folderCopyLastWrittenAt"
        static let lastFailure = "folderCopyLastFailure"
    }

    /// How long after the last change the file is written. Long enough that a
    /// reader painting three highlights in a row produces one write, short
    /// enough that the file is on its way before they put the phone down.
    static let debounce: Duration = .seconds(3)

    private static var pending: Task<Void, Never>?
    private static var pendingContext: ModelContext?

    private static var defaults: UserDefaults { .standard }

    // MARK: - State the screen shows

    static var isConfigured: Bool {
        defaults.data(forKey: Key.bookmark) != nil
    }

    // MARK: - Choosing and forgetting

    /// Remembers `folder` and writes the file into it straight away, so the
    /// reader sees it appear rather than wondering whether anything happened.
    ///
    /// `folder` comes from a picker, and on iOS it is readable only inside its
    /// security scope — which is why the scope is opened here, around both the
    /// bookmark and the first write.
    static func choose(folder: URL, in context: ModelContext) {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }

        do {
            let bookmark = try FolderCopy.bookmark(for: folder)
            defaults.set(bookmark, forKey: Key.bookmark)
            defaults.set(folder.lastPathComponent, forKey: Key.folderName)
            defaults.removeObject(forKey: Key.lastWrittenAt)
            defaults.removeObject(forKey: Key.lastFailure)
        } catch let failure as FolderCopy.Failure {
            defaults.set(failure.errorDescription ?? "", forKey: Key.lastFailure)
            return
        } catch {
            defaults.set(FolderCopy.Failure.notRemembered.errorDescription ?? "", forKey: Key.lastFailure)
            return
        }
        writeNow(in: context)
    }

    /// Stops writing. The file already in the folder is the reader's and is
    /// left where it is.
    static func forget() {
        pending?.cancel()
        pending = nil
        pendingContext = nil
        for key in [Key.bookmark, Key.folderName, Key.lastWrittenAt, Key.lastFailure] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Writing

    /// Called by the stores after a highlight, note or bookmark changes. Cheap
    /// when no folder is chosen; otherwise starts the debounce over.
    static func noteChange(in context: ModelContext) {
        guard isConfigured else { return }
        pendingContext = context
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    /// Writes now if a change is waiting. The app calls this as it leaves the
    /// foreground, so a mark made just before the phone was put away still
    /// reaches the folder.
    static func flush() {
        pending?.cancel()
        pending = nil
        guard let context = pendingContext else { return }
        pendingContext = nil
        writeNow(in: context)
    }

    /// Writes the file whether or not anything changed. The screen's
    /// "Write now" and the moment a folder is chosen both come here.
    static func writeNow(in context: ModelContext) {
        guard let stored = defaults.data(forKey: Key.bookmark) else { return }
        do {
            let resolved = try FolderCopy.resolve(stored)
            if let refreshed = resolved.refreshedBookmark {
                defaults.set(refreshed, forKey: Key.bookmark)
                defaults.set(resolved.url.lastPathComponent, forKey: Key.folderName)
            }
            let document = BackupService.makeDocument(in: context)
            let data = try BackupDocument.encode(document)
            try FolderCopy.write(
                data, named: FolderCopy.filename(deviceName: deviceName), into: resolved.url
            )
            defaults.set(Date().timeIntervalSinceReferenceDate, forKey: Key.lastWrittenAt)
            defaults.removeObject(forKey: Key.lastFailure)
        } catch let failure as FolderCopy.Failure {
            defaults.set(failure.errorDescription ?? "", forKey: Key.lastFailure)
        } catch {
            defaults.set("The copy could not be written.", forKey: Key.lastFailure)
        }
    }

    // MARK: - Which device wrote this

    /// Part of the filename, so two devices sharing one folder each keep their
    /// own file. iOS has answered with the model name rather than the reader's
    /// own name since iOS 16, which still tells an iPhone from an iPad.
    private static var deviceName: String {
        #if os(iOS) || os(tvOS)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "Mac"
        #endif
    }
}
