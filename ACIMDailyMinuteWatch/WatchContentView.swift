import SwiftUI
import SwiftData

struct WatchContentView: View {
    @State private var minute: DailyMinute? = nil
    @State private var lessonNumber: Int? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    if let minute {
                        WatchStoryRow(minute: minute, lessonNumber: lessonNumber)
                    } else {
                        Text("No content yet")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("ACIM Daily Minute")
        }
        .task {
            minute = await WatchDataService.shared.fetchTodaysMinute()
            lessonNumber = await WatchDataService.shared.fetchTodaysLessonNumber()
        }
    }
}
