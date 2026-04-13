import SwiftUI

struct ArchiveView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Archive", systemImage: "archivebox.fill")
            } description: {
                Text("Full archive browser with calendar and search arrives in Phase 3.7.")
            }
            .navigationTitle("Archive")
        }
    }
}

#Preview {
    ArchiveView()
        .preferredColorScheme(.dark)
}
