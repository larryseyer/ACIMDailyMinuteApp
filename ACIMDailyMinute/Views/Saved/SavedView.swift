import SwiftUI

struct SavedView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Saved", systemImage: "bookmark.fill")
            } description: {
                Text("Bookmarks list arrives in Phase 3.8.")
            }
            .navigationTitle("Saved")
        }
    }
}

#Preview {
    SavedView()
        .preferredColorScheme(.dark)
}
