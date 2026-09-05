// ⛔ tvOS has no document picker of any kind — no fileImporter, no
// fileExporter, no FileDocument — so neither tier of the backup can be
// operated there: not the Save/Restore file and not the folder a reader
// chooses. This screen therefore does not exist on the TV.
//
// ⛔ That is also WHY a tvOS reader must not be invited to create
// annotations: the container is purgeable there and the one route that
// could carry their words off the device is unavailable.
#if !os(tvOS)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// One plain JSON file, holding everything the reader has made.
///
/// It is `.json` and not a private extension on purpose: the file has to open on
/// a Windows, Linux or Android machine with what that machine already has. A
/// format only this app could read would recreate the trap it exists to prevent.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupRestoreView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportFile: BackupFile?
    @State private var exportName = "ACIM Daily Minute backup.json"
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var restoreSettings = true
    @State private var outcome: Outcome?
    @State private var isChoosingFolder = false

    /// Bound to the keys `FolderCopyService` writes, so the section redraws
    /// when a write lands or fails — the service is a plain enum SwiftUI has no
    /// dependency on otherwise.
    @AppStorage(FolderCopyService.Key.bookmark) private var folderBookmark = Data()
    @AppStorage(FolderCopyService.Key.folderName) private var folderName = ""
    @AppStorage(FolderCopyService.Key.lastWrittenAt) private var folderLastWrittenAt = 0.0
    @AppStorage(FolderCopyService.Key.lastFailure) private var folderFailure = ""

    private enum Outcome: Equatable {
        case saved
        case imported(BackupMerge.MergePlan)
        case failed(String)

        var isFailure: Bool {
            if case .failed = self { return true }
            return false
        }
    }

    var body: some View {
        Form {
            Section {
                Button("Save a backup…") { beginExport() }
            } header: {
                Text("Save")
            } footer: {
                Text(
                    "Writes everything you have made — your highlights, notes, bookmarks, "
                    + "listened history and reminder settings — into one "
                    + "plain file you can keep anywhere and open on any computer."
                )
            }

            Section {
                Toggle("Restore settings too", isOn: $restoreSettings)
                Button("Restore from a file…") { isImporting = true }
            } header: {
                Text("Restore")
            } footer: {
                // The whole merge design rests on this sentence, and a reader is
                // entitled to know it before they tap rather than afterwards.
                Text(
                    "Restoring never removes anything. Marks you already have are kept, "
                    + "anything new is added, and a note you wrote on two devices ends up "
                    + "holding both versions rather than losing one.\n\n"
                    + "Leave “Restore settings too” off to bring across only your highlights, "
                    + "notes and bookmarks. Listened history is always "
                    + "merged, because merging it cannot lose anything."
                )
            }

            if let outcome {
                Section("Last action") {
                    Text(message(for: outcome))
                        .foregroundStyle(outcome.isFailure ? .red : .primary)
                }
            }

            Section {
                if folderBookmark.isEmpty {
                    Button("Choose a folder…") { isChoosingFolder = true }
                } else {
                    LabeledContent("Folder", value: folderName)
                    if !folderFailure.isEmpty {
                        Text(folderFailure)
                            .foregroundStyle(.red)
                    } else if folderLastWrittenAt > 0 {
                        LabeledContent(
                            "Last written",
                            value: Date(timeIntervalSinceReferenceDate: folderLastWrittenAt)
                                .formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                    Button("Write now") { FolderCopyService.writeNow(in: modelContext) }
                    Button("Choose a different folder…") { isChoosingFolder = true }
                    Button("Stop keeping a copy", role: .destructive) { FolderCopyService.forget() }
                }
            } header: {
                Text("Keep a copy in a folder")
            } footer: {
                // The second sentence is the boundary of this feature. Nothing
                // is ever read from the folder by itself: a folder two machines
                // both write into is where an automatic merge would lose words.
                Text(
                    "Writes the same backup file into a folder you choose, by itself, whenever "
                    + "your highlights, notes or bookmarks change. Point it at a folder your "
                    + "Dropbox, Drive or Syncthing already carries and the file follows you.\n\n"
                    + "Nothing is read from the folder on its own. To bring work in from another "
                    + "device, restore its file from the section above."
                )
            }

            Section {
                Text(
                    "This file is for carrying your work to another device, and it can be read "
                    + "back in. “Export as text” in the Saved tab writes your highlights and "
                    + "notes as prose for reading, and cannot."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .readableContentWidth()
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle("Backup & Restore")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // A restore onto a device with nothing on it should bring settings
            // with it; a merge into work in progress should not reach over and
            // change them unasked.
            restoreSettings = BackupService.shouldRestoreSettingsByDefault(in: modelContext)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportFile,
            contentType: .json,
            defaultFilename: exportName
        ) { result in
            switch result {
            case .success: outcome = .saved
            case .failure(let error): outcome = .failed(error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): performImport(from: url)
            case .failure(let error): outcome = .failed(error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): FolderCopyService.choose(folder: url, in: modelContext)
            case .failure(let error): folderFailure = error.localizedDescription
            }
        }
    }

    private func beginExport() {
        let document = BackupService.makeDocument(in: modelContext)
        do {
            exportFile = BackupFile(data: try BackupDocument.encode(document))
            exportName = BackupService.suggestedFilename(for: document)
            isExporting = true
        } catch {
            outcome = .failed("The backup could not be written.")
        }
    }

    private func performImport(from url: URL) {
        // A file chosen from iCloud Drive or another app's folder arrives
        // security-scoped, and reading it without asking first fails.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let document = try BackupDocument.decode(try Data(contentsOf: url))
            let plan = try BackupService.apply(
                document, restoreSettings: restoreSettings, in: modelContext
            )
            outcome = .imported(plan)
        } catch let failure as BackupDocument.Failure {
            outcome = .failed(failure.errorDescription ?? "That backup could not be read.")
        } catch {
            outcome = .failed("That backup could not be read.")
        }
    }

    private func message(for outcome: Outcome) -> String {
        switch outcome {
        case .saved:
            "Backup saved."
        case .failed(let reason):
            reason
        case .imported(let plan):
            importSummary(plan)
        }
    }

    private func importSummary(_ plan: BackupMerge.MergePlan) -> String {
        var parts: [String] = []
        if !plan.insertHighlights.isEmpty {
            parts.append(count(plan.insertHighlights.count, "highlight", "highlights"))
        }
        if !plan.insertNotes.isEmpty {
            parts.append(count(plan.insertNotes.count, "note", "notes"))
        }
        if !plan.insertBookmarks.isEmpty {
            parts.append(count(plan.insertBookmarks.count, "bookmark", "bookmarks"))
        }

        var lines: [String] = []
        if parts.isEmpty {
            lines.append("Everything in that backup was already here.")
        } else {
            lines.append("Added \(list(parts)).")
        }
        if plan.mergedNoteCount > 0 {
            let notes = count(plan.mergedNoteCount, "note", "notes")
            let verb = plan.mergedNoteCount == 1 ? "was" : "were"
            lines.append("\(notes.capitalizedFirst) \(verb) written in two places and now hold"
                         + (plan.mergedNoteCount == 1 ? "s" : "") + " both versions.")
        }
        lines.append("Nothing was removed.")
        return lines.joined(separator: " ")
    }

    private func count(_ number: Int, _ singular: String, _ plural: String) -> String {
        "\(number) \(number == 1 ? singular : plural)"
    }

    private func list(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " and " + (parts.last ?? "")
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

#Preview {
    NavigationStack {
        BackupRestoreView()
    }
    .preferredColorScheme(.dark)
}
#endif
