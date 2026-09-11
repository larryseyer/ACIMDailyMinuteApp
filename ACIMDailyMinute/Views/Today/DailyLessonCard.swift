import SwiftUI

struct DailyLessonCard: View {
    let lesson: DailyLesson

    @AppStorage(WorkbookCompletion.defaultsKey) private var completedBlob: Data = Data()
    @AppStorage(ReadingPositionStore.defaultsKey) private var ribbonBlob: Data = Data()

    var body: some View {
        #if os(tvOS)
        card
        #else
        NavigationLink(value: LessonRef(lessonNumber: lesson.lessonNumber, presentsVideo: false)) {
            card
        }
        .buttonStyle(.plain)
        #endif
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Lesson \(lesson.lessonNumber)")
                    .font(.acimCardTitle)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                CitationLabel(raw: "W-\(lesson.lessonNumber)", font: .acimAddressSmall)
            }
            if let line = bodyLine {
                (
                    Text(line.prefix)
                    + Text(line.emphasis).italic()
                )
                    .font(.acimCardBody)
                    .foregroundStyle(.primary)
                    .lineSpacing(Metric.cardBodyGap)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)
            }
            if let fraction = progressFraction {
                hairline(fraction)
                    .padding(.top, 11)
            }
        }
        .todaySurfaceCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var lessonTitle: String {
        if !lesson.lessonTitle.isEmpty { return lesson.lessonTitle }
        return WorkbookCatalog.title(for: lesson.lessonNumber) ?? ""
    }

    private var bodyLine: (prefix: String, emphasis: String)? {
        let title = lessonTitle
        if let review = WorkbookBodiesCatalog.reviewTitle(for: lesson.lessonNumber) {
            if title.isEmpty { return (review, "") }
            return ("\(review) — ", title)
        }
        if title.isEmpty { return nil }
        return ("", title)
    }

    private var progressFraction: CGFloat? {
        _ = completedBlob
        _ = ribbonBlob
        if WorkbookCompletion.doneAt(lesson.lessonNumber) != nil { return 1 }
        guard let position = ReadingPositionStore.position(matching: .lesson(lesson.lessonNumber)) else {
            return nil
        }
        let count = ReadingText.displayString(from: lesson.text).count
        guard count > 0 else { return nil }
        return min(1, CGFloat(position.startOffset) / CGFloat(count))
    }

    private func hairline(_ fraction: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.acimRaised)
                Rectangle()
                    .fill(Color.acimGold)
                    .frame(width: max(0, geometry.size.width * fraction))
            }
        }
        .frame(height: Metric.progressHairline)
    }

    private var accessibilityText: String {
        var parts = ["Lesson \(lesson.lessonNumber)"]
        if let line = bodyLine {
            parts.append(line.prefix + line.emphasis)
        }
        return parts.joined(separator: ", ")
    }
}
