import SwiftUI

#if !os(tvOS)

/// Today's next-practice card. Surface only — every time comes from
/// `PracticePlanner`. The sheet that opens it is step 3.
struct PracticeCard: View {
    var body: some View {
        if let lesson, let record {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Next practice")
                        .font(.acimCardTitle)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if let next = nextSlot {
                        Text(Self.timeText(next.time))
                            .font(.acimChipText)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.acimRaised)
                            .clipShape(Capsule())
                    }
                }
                Text(PracticePlanner.cadenceSummary(record))
                    .font(.acimCardBody)
                    .foregroundStyle(.primary)
                    .lineSpacing(Metric.cardBodyGap)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .todaySurfaceCard()
            .accessibilityElement(children: .combine)
        }
    }

    private var lesson: Int? {
        PracticeReminderService.currentLesson()
    }

    private var record: PracticeRecord? {
        lesson.flatMap { WorkbookPracticeCatalog.record(for: $0) }
    }

    private var nextSlot: PracticePlanner.Slot? {
        guard let record else { return nil }
        let now = Self.nowTime
        return PracticePlanner.slots(for: record, in: PracticeReminderService.window())
            .first { $0.time >= now }
    }

    private static var nowTime: TimeOfDay {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    private static func timeText(_ time: TimeOfDay) -> String {
        let hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12
        let suffix = time.hour < 12 ? "am" : "pm"
        if time.minute == 0 { return "\(hour12) \(suffix)" }
        return String(format: "%d:%02d %@", hour12, time.minute, suffix)
    }
}

#endif
