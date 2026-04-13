import SwiftUI

/// Single row in the Lessons workbook list.
///
/// Tap is wired through a `NavigationLink(value: Int)`. The matching
/// `.navigationDestination(for: Int.self)` lands on `LessonsView` in Phase 3.5b.
/// Until then the row renders but tap is inert by design.
struct LessonRow: View {
    let lessonNumber: Int
    let meta: LessonMeta?
    let isBookmarked: Bool

    private static let accent = Color(red: 0.83, green: 0.69, blue: 0.22)

    var body: some View {
        NavigationLink(value: lessonNumber) {
            HStack(spacing: 12) {
                numberBadge
                titleColumn
                Spacer(minLength: 8)
                if isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(Self.accent)
                        .accessibilityLabel("Bookmarked")
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
    }

    private var numberBadge: some View {
        Text("\(lessonNumber)")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Self.accent)
            .clipShape(Capsule())
            .accessibilityLabel("Lesson \(lessonNumber)")
    }

    @ViewBuilder
    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title = meta?.title, !title.isEmpty {
                Text(title)
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not yet read")
                    .font(.custom("Georgia", size: 15).italic())
                    .foregroundStyle(.secondary)
            }

            if let dateRead = meta?.dateRead, !dateRead.isEmpty {
                Text(dateRead)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
