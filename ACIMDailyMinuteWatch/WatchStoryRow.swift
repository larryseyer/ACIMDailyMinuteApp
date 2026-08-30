import SwiftUI

struct WatchStoryRow: View {
    let minute: DailyMinute
    var lessonNumber: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let n = lessonNumber {
                Text("Lesson \(n)")
                    .font(.caption2)
                    .foregroundStyle(.tint)
            }
            // The watch has no reading surface, so it repairs the feed's
            // spacing where it draws it.
            Text(PunctuationSpacing.repaired(minute.text))
                .font(.footnote)
                .lineLimit(6)
        }
    }
}
