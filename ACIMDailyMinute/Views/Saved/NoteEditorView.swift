// ⛔ tvOS has no TextEditor, and no text selection either — the whole
// selection→highlight→note pipeline has no port to a television. This is
// absent there by construction rather than by removal: a reader cannot
// make a note on the TV, so the editor does not exist there.
#if !os(tvOS)
import SwiftUI

/// Where a reader writes.
///
/// A text editor, Save, and Cancel. There is deliberately no microphone button:
/// dictation is the system keyboard's own, which costs no framework, no
/// `Info.plist` key and no permission prompt. A button here would imply a
/// `Speech` dependency, and this app carries zero `UsageDescription` keys.
struct NoteEditorView: View {
    let readingName: String
    /// The passage this note is about, when it is about a passage.
    let quote: String?
    let onSave: (String) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    init(readingName: String, quote: String?, existing: String = "", onSave: @escaping (String) -> Void) {
        self.readingName = readingName
        self.quote = quote
        self.onSave = onSave
        _text = State(initialValue: existing)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(readingName)
                    .font(.acimCaption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                if let quote, !quote.isEmpty {
                    Text(quote)
                        .font(.system(.subheadline, design: .serif).italic())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 10)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.4))
                                .frame(width: 2)
                        }
                }

                TextEditor(text: $text)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .background(Color.acimChip)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)
                    .frame(minHeight: 180)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle("Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear { isFocused = true }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 340)
        #endif
    }
}
#endif
