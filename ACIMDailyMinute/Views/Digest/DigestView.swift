import SwiftUI

struct DigestView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Listen", systemImage: "play.circle.fill")
            } description: {
                Text("Podcast feed and audio playback arrive in Phase 3.6.")
            }
            .navigationTitle("Listen")
        }
    }
}

#Preview {
    DigestView()
        .preferredColorScheme(.dark)
}
