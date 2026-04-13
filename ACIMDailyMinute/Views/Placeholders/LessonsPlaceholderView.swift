import SwiftUI

struct LessonsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Lessons", systemImage: "book.closed.fill")
            } description: {
                Text("Workbook browser with \"Jump to Lesson N\" arrives in Phase 3.5.")
            }
            .navigationTitle("Lessons")
        }
    }
}

#Preview {
    LessonsPlaceholderView()
        .preferredColorScheme(.dark)
}
