import SwiftUI

// MARK: - Storage

enum WatchedTermsStorage {
    static let maxTerms = 10

    static var terms: [String] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchedTerms"),
                  let decoded = try? JSONDecoder().decode([String].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "watchedTerms")
        }
    }

    static var notifiedHashes: Set<String> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "watchedTermsNotifiedHashes"),
                  let decoded = try? JSONDecoder().decode(Set<String>.self, from: data)
            else { return [] }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: "watchedTermsNotifiedHashes")
        }
    }
}

// MARK: - View

struct WatchedTermsView: View {
    @State private var terms: [String] = WatchedTermsStorage.terms
    @State private var newTerm = ""

    var body: some View {
        Form {
            Section {
                if terms.isEmpty {
                    Text("No watched terms yet. Add one below to get notified when matching facts are published.")
                        .font(.acimCallout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(terms, id: \.self) { term in
                        termRow(term)
                    }
                    .onDelete(perform: deleteTerm)
                }
            } header: {
                Text("Terms (\(terms.count)/\(WatchedTermsStorage.maxTerms))")
            } footer: {
                Text("Case-insensitive match against story text. All matching is done on-device.")
                    .font(.acimCaption)
            }

            if terms.count < WatchedTermsStorage.maxTerms {
                Section("Add Term") {
                    HStack {
                        TextField("New term", text: $newTerm)
                            .autocorrectionDisabled()
                            .onSubmit { addTerm() }
                        Button("Add") { addTerm() }
                            .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Watched Terms")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        #endif
    }

    @ViewBuilder
    private func termRow(_ term: String) -> some View {
        #if os(macOS)
        // macOS has no EditButton / swipe-to-delete affordance, so give
        // each row an inline trash action so users can actually remove
        // terms without hunting for a gesture.
        HStack {
            Text(term)
                .font(.acimBody)
            Spacer()
            Button {
                delete(term)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .help("Remove this term")
        }
        #else
        Text(term)
            .font(.acimBody)
        #endif
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !terms.contains(where: { $0.lowercased() == trimmed.lowercased() }) else { return }
        terms.append(trimmed)
        newTerm = ""
        save()
    }

    private func deleteTerm(at offsets: IndexSet) {
        terms.remove(atOffsets: offsets)
        save()
    }

    private func delete(_ term: String) {
        terms.removeAll { $0 == term }
        save()
    }

    private func save() {
        WatchedTermsStorage.terms = terms
        WatchedTermsStorage.notifiedHashes = []
    }
}
