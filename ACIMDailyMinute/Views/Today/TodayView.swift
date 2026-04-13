import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Today", systemImage: "sun.max.fill")
            } description: {
                Text("Daily Minute + Daily Lesson cards arrive in Phase 3.4b.")
            }
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
        .preferredColorScheme(.dark)
}
