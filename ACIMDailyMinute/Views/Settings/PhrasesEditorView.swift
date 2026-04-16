import SwiftUI

struct PhrasesEditorView: View {
    @State private var draft = ""
    @State private var phrases: [String] = PhraseStorage.phrases

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
            && phrases.count < PhraseStorage.maxPhrases
    }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add a phrase", text: $draft)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .onSubmit { addPhrase() }
                    Button("Add") { addPhrase() }
                        .disabled(!canAdd)
                }
            }

            Section {
                ForEach(phrases, id: \.self) { phrase in
                    Text(phrase)
                }
                .onDelete(perform: deletePhrase)
            } footer: {
                Text("\(phrases.count) of \(PhraseStorage.maxPhrases)")
            }
        }
        .readableContentWidth()
        .navigationTitle("Watched Phrases")
    }

    private func addPhrase() {
        guard canAdd else { return }
        PhraseStorage.add(draft)
        phrases = PhraseStorage.phrases
        draft = ""
    }

    private func deletePhrase(at offsets: IndexSet) {
        for index in offsets.sorted().reversed() {
            PhraseStorage.remove(at: index)
        }
        phrases = PhraseStorage.phrases
    }
}

#Preview {
    NavigationStack {
        PhrasesEditorView()
    }
    .preferredColorScheme(.dark)
}
