import SwiftUI

/// Single row in the Lessons workbook list.
///
/// Recorded lessons tap through a `NavigationLink(value: Int)` to the matching
/// `.navigationDestination(for: Int.self)` on `LessonsView`. Lessons the
/// publisher has not reached yet render dimmed and *without* the link, so the
/// row is inert rather than opening a screen with nothing on it — the second
/// line carries the date the recording is due instead.
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
        if isAvailable {
            NavigationLink(value: lessonNumber) {
                rowContent
            }
        } else {
            rowContent
                .accessibilityElement(children: .combine)
                .accessibilityLabel(unavailableAccessibilityLabel)
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
                Text("Available \(Self.availabilityFormatter.string(from: availableOn))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Formatting

    /// Deliberately the publisher's own `yyyy-MM-dd`, matching how every other
    /// date in the app's data is written, so a reader can line the row up
    /// against the feed without translating formats.
    private static let availabilityFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        // Must match the zone the date was computed in, or the printed day
        // slips either side of midnight depending on where the reader is.
        f.timeZone = LessonSchedule.publicationCalendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var unavailableAccessibilityLabel: String {
        let title = resolvedTitle ?? "Lesson \(lessonNumber)"
        guard let availableOn else { return title }
        return "Lesson \(lessonNumber), \(title). Not recorded yet. Available \(Self.availabilityFormatter.string(from: availableOn))."
    }
}
