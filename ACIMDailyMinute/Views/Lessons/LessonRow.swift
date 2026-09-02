import SwiftUI

/// Single row in the Lessons workbook list.
///
/// Every lesson taps through a `NavigationLink(value: Int)` to the matching
/// `.navigationDestination(for: Int.self)` on `LessonsView`. A lesson the
/// publisher has not reached yet renders dimmed, with the date its recording is
/// due on the second line — and still opens, because its text is bundled and
/// readable now; only the audio and video are still to come. The screen it
/// opens repeats the date, so a tap is answered rather than ignored.
struct LessonRow: View {
    let lessonNumber: Int
    let meta: LessonMeta?
    let isBookmarked: Bool

    /// `nil` once the lesson has been recorded. Non-nil is what makes the row
    /// dim and inert, so the two states cannot drift apart.
    let availableOn: Date?

    private static let accent = Color(red: 0.83, green: 0.69, blue: 0.22)

    private var isAvailable: Bool { availableOn == nil }

    var body: some View {
        NavigationLink(value: lessonNumber) {
            if isAvailable {
                rowContent
            } else {
                rowContent
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(unavailableAccessibilityLabel)
            }
        }
    }

    private var rowContent: some View {
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

    private var numberBadge: some View {
        Text("\(lessonNumber)")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(isAvailable ? .black : .white.opacity(0.55))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isAvailable ? AnyShapeStyle(Self.accent) : AnyShapeStyle(.tertiary))
            .clipShape(Capsule())
            .accessibilityLabel("Lesson \(lessonNumber)")
    }

    private var resolvedTitle: String? {
        if let title = meta?.title, !title.isEmpty { return title }
        return WorkbookCatalog.title(for: lessonNumber)
    }

    @ViewBuilder
    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title = resolvedTitle {
                Text(title)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(isAvailable ? .primary : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not yet read")
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(.secondary)
            }

            if let availableOn {
                Text("Available \(LessonSchedule.formatted(availableOn))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var unavailableAccessibilityLabel: String {
        let title = resolvedTitle ?? "Lesson \(lessonNumber)"
        guard let availableOn else { return title }
        return "Lesson \(lessonNumber), \(title). Not recorded yet. Available \(LessonSchedule.formatted(availableOn))."
    }
}
