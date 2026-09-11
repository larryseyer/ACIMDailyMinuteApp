import SwiftUI

#if !os(tvOS)

/// Today's practice schedule. Surface only — every time comes from
/// `PracticePlanner`. The card that opens it is `PracticeCard`.
struct PracticeSheet: View {
    var onBegin: () -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage(PracticeReminderKey.windowStart) private var windowStart = 0.0
    @AppStorage(PracticeReminderKey.windowEnd) private var windowEnd = 0.0
    @AppStorage(PracticeReminderKey.ownStartLesson) private var ownStartLesson = 0
    @AppStorage(PracticeReminderKey.ownStartDay) private var ownStartDay = ""
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grab
            if let lesson, let record {
                Text("Practice for Lesson \(lesson)")
                    .font(.system(size: 23, design: .serif))
                    .padding(.bottom, 4)
                Text(PracticePlanner.cadenceSummary(record))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
                ScrollView {
                    slotList
                }
            }
            actions
        }
        .padding(.horizontal, Metric.gutter)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.acimSurface)
        .readableContentWidth()
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        #if os(iOS)
        .presentationDetents([.fraction(0.66), .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(Metric.sheet)
        .presentationBackground(Color.acimSurface)
        #endif
        #if os(macOS)
        .background(QuittableSheet())
        #endif
    }

    private var grab: some View {
        Capsule()
            .fill(.tertiary.opacity(0.5))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .accessibilityHidden(true)
    }

    private var slotList: some View {
        VStack(spacing: 0) {
            ForEach(slots, id: \.time) { slot in
                slotRow(slot)
            }
        }
    }

    private func slotRow(_ slot: PracticePlanner.Slot) -> some View {
        let isNext = slot.time == nextSlot?.time
        let isPast = slot.time < nowTime
        return HStack(alignment: .center, spacing: 14) {
            Text(Self.timeText(slot.time))
                .font(.system(size: 15, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.acimGold)
                .frame(width: 66, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.title(for: slot))
                    .font(.system(size: 14))
                if let line = Self.sub(for: slot, isNext: isNext) {
                    Text(line)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
            ZStack {
                if isNext {
                    Circle()
                        .fill(Color.acimGold.opacity(0.22))
                        .frame(width: 16, height: 16)
                }
                Circle()
                    .fill(isNext ? Color.acimGold : Color.acimRaised)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 16, height: 16)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Color.acimHairline.frame(height: 1)
        }
        .opacity(isPast ? 0.4 : 1)
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        HStack(spacing: 9) {
            if let title = beginTitle {
                Button {
                    onBegin()
                    dismiss()
                } label: {
                    Text(title)
                        .font(.acimChrome)
                        .foregroundStyle(Color.acimOnGold)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(Color.acimGold, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            Spacer(minLength: 0)
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.acimChrome)
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(Color.acimRaised, in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Practice settings")
        }
        .padding(.top, 22)
    }

    // MARK: - Data

    private var lesson: Int? {
        _ = ownStartLesson
        _ = ownStartDay
        return PracticeReminderService.currentLesson()
    }

    private var record: PracticeRecord? {
        lesson.flatMap { WorkbookPracticeCatalog.record(for: $0) }
    }

    private var window: PracticeWindow {
        _ = windowStart
        _ = windowEnd
        return PracticeReminderService.window()
    }

    private var slots: [PracticePlanner.Slot] {
        guard let record else { return [] }
        return PracticePlanner.slots(for: record, in: window)
    }

    private var nowTime: TimeOfDay {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    private var nextSlot: PracticePlanner.Slot? {
        slots.first { $0.time >= nowTime }
    }

    private var beginTitle: String? {
        guard let next = nextSlot else { return nil }
        switch next.kind {
        case .session:
            switch next.sessionName {
            case "Morning practice": return "Begin the morning period"
            case "Evening practice": return "Begin the evening period"
            default: return "Begin the practice period"
            }
        case .hour, .halfHour, .short:
            return "Begin this practice"
        }
    }

    // MARK: - Copy

    private static func title(for slot: PracticePlanner.Slot) -> String {
        switch slot.kind {
        case .session: return slot.sessionName
        case .hour: return "Hourly practice"
        case .halfHour: return "Half-hour practice"
        case .short: return "Practice \(slot.ordinal) of \(slot.count)"
        }
    }

    private static func sub(for slot: PracticePlanner.Slot, isNext: Bool) -> String? {
        var line: String?
        switch slot.kind {
        case .session:
            line = slot.minutes > 0 ? minuteLine(slot.minutes) : "As long as you can"
        case .hour, .halfHour, .short:
            if slot.minutes > 0 { line = minuteLine(slot.minutes) }
        }
        if isNext {
            line = line.map { "\($0) · next" } ?? "next"
        }
        return line
    }

    private static func minuteLine(_ minutes: Int) -> String {
        minutes == 1 ? "A minute" : "\(words(minutes).capitalized) minutes"
    }

    private static func words(_ number: Int) -> String {
        let small = [
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
            "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen",
            "nineteen", "twenty"
        ]
        if number >= 0, number < small.count { return small[number] }
        if number == 30 { return "thirty" }
        return String(number)
    }

    private static func timeText(_ time: TimeOfDay) -> String {
        let hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12
        let suffix = time.hour < 12 ? "am" : "pm"
        if time.minute == 0 { return "\(hour12) \(suffix)" }
        return String(format: "%d:%02d %@", hour12, time.minute, suffix)
    }
}

#endif
