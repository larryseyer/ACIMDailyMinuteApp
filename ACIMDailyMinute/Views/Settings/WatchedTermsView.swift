import SwiftUI

struct WatchedTermsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Phrases", systemImage: "eye.fill")
            } description: {
                Text("Watched phrases editor arrives in Phase 3.8.")
            }
            .navigationTitle("Phrases")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
    }
}

#Preview {
    WatchedTermsView()
        .preferredColorScheme(.dark)
}
