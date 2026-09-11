import SwiftUI

/// One Workbook spine row. Number, title, sub, media glyphs.
///
/// An unpublished lesson is inert: the text is bundled, but the row does
/// not open until `LessonSchedule` says it is due. The current lesson is
/// the highlighted row — gold at 9%, bled 12pt into the gutters.
struct LessonRow: View {
    let lessonNumber: Int
    let meta: LessonMeta?
    let isBookmarked: Bool
    let isCompleted: Bool
    let availableOn: Date?
    var isCurrent: Bool = false
    var practiceLine: String? = nil

    private var isAvailable: Bool { availableOn == nil }

    var body: some View {
        Group {
            if isAvailable {
                NavigationLink(value: lessonNumber) { rowLabel }
                    .buttonStyle(.plain)
            } else {
                rowLabel
                    .opacity(0.42)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(unavailableAccessibilityLabel)
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 13))
        .listRowBackground(Color.clear)
        #if !os(tvOS)
        .listRowSeparator(.hidden)
        #endif
    }

    private var rowLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 13) {
            Text("\(lessonNumber)")
                .font(.acimRowNumber)
                .foregroundStyle(Color.acimGold)
                .frame(width: 34, alignment: .leading)
                .accessibilityLabel("Lesson \(lessonNumber)")

            VStack(alignment: .leading, spacing: 2) {
                Text(resolvedTitle ?? "Lesson \(lessonNumber)")
                    .font(.acimRowTitle)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if let sub = subtitle {
                    Text(sub)
                        .font(.acimRowSub)
                        .foregroundStyle(isCurrent ? Color.acimGold : Color.secondary)
                }
            }

            Spacer(minLength: 8)

            CourseSpineGlyphs(hasAudio: meta?.hasAudio == true, hasVideo: meta?.hasVideo == true)
        }
        .padding(.vertical, Metric.row)
        .padding(.horizontal, 12)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.acimGold.opacity(0.09))
                    .padding(.horizontal, -12)
            }
        }
        .contentShape(Rectangle())
    }

    private var titleColor: Color {
        if !isAvailable { return .primary }
        if isCompleted { return .secondary }
        return .primary
    }

    private var resolvedTitle: String? {
        if let title = meta?.title, !title.isEmpty { return title }
        return WorkbookCatalog.title(for: lessonNumber)
    }

    private var subtitle: String? {
        if isCurrent, let practiceLine, !practiceLine.isEmpty {
            return practiceLine
        }
        if let availableOn {
            return "Available \(LessonSchedule.formatted(availableOn))"
        }
        if isBookmarked { return nil }
        return nil
    }

    private var unavailableAccessibilityLabel: String {
        let title = resolvedTitle ?? "Lesson \(lessonNumber)"
        guard let availableOn else { return title }
        return "Lesson \(lessonNumber), \(title). Not recorded yet. Available \(LessonSchedule.formatted(availableOn))."
    }
}
