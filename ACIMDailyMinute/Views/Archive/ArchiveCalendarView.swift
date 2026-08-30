import SwiftUI

/// The Archive calendar, used on every platform.
///
/// Replaces SwiftUI's graphical `DatePicker` on iOS as well as `NSDatePicker`
/// on macOS. The system pickers can only answer "what date is selected"; this
/// one also shows *which days actually hold readings*, and draws a selection
/// that stays legible on the dark ground.
struct ArchiveCalendarView: View {
    @Binding var selection: Date

    /// `yyyy-MM-dd` strings that have at least one archived reading. Matching
    /// on the formatted string rather than a `Date` avoids every timezone and
    /// start-of-day trap in comparing instants across a calendar grid.
    let availableDateStrings: Set<String>

    @State private var visibleMonth: Date

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1 // Sunday
        return c
    }()

    init(selection: Binding<Date>, availableDateStrings: Set<String> = []) {
        self._selection = selection
        self.availableDateStrings = availableDateStrings
        self._visibleMonth = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            monthGrid
        }
        .padding(14)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onChange(of: selection) { _, newValue in
            if !calendar.isDate(newValue, equalTo: visibleMonth, toGranularity: .month) {
                visibleMonth = newValue
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(monthYearText)
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.acimSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let days = monthDays
        let rows = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }
        return VStack(spacing: 4) {
            ForEach(0..<rows.count, id: \.self) { rowIdx in
                HStack(spacing: 0) {
                    ForEach(rows[rowIdx], id: \.self) { date in
                        dayCell(date)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let isInCurrentMonth = calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(date)
        let hasReadings = availableDateStrings.contains(Self.dateString(from: date))
        let day = calendar.component(.day, from: date)

        Button {
            selection = date
        } label: {
            ZStack {
                if isSelected {
                    // The accent is a light cream, so the filled disc already
                    // separates itself from the dark ground. No outline: a
                    // white ring on a light fill just muddies the edge.
                    Circle()
                        .fill(Color.accentColor)
                } else if isToday {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 1.5)
                } else if hasReadings {
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                }

                VStack(spacing: 2) {
                    Text("\(day)")
                        .font(.system(
                            size: 17,
                            weight: isSelected || isToday || hasReadings ? .semibold : .regular
                        ))
                        .foregroundStyle(foregroundColor(
                            selected: isSelected,
                            today: isToday,
                            hasReadings: hasReadings
                        ))
                    // The dot repeats the "has readings" signal in a second
                    // channel, so it survives colour-blindness and the tinted
                    // disc being hidden under the selection.
                    Circle()
                        .fill(isSelected ? Self.onAccent : Color.accentColor)
                        .frame(width: 4, height: 4)
                        .opacity(hasReadings ? 1 : 0)
                }
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isInCurrentMonth ? 1.0 : 0.35)
        .accessibilityLabel(accessibilityLabel(for: date, hasReadings: hasReadings))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func foregroundColor(selected: Bool, today: Bool, hasReadings: Bool) -> Color {
        // Dark on the accent fill. The accent is light, so white-on-accent is
        // the one combination in this view that cannot be read.
        if selected { return Self.onAccent }
        if today { return .accentColor }
        // Days with nothing to read are dimmed rather than days with readings
        // being brightened, so the month reads as "these are the live ones".
        return hasReadings ? .primary : .secondary
    }

    private func accessibilityLabel(for date: Date, hasReadings: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        let base = formatter.string(from: date)
        return hasReadings ? "\(base), has readings" : base
    }

    /// Foreground for anything drawn on top of the accent fill.
    private static let onAccent = Color(white: 0.07)

    static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Computed

    private var monthYearText: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    private var monthDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = monthInterval.start

        // Days to pad at start (so first cell is on the firstWeekday)
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingPad = (weekday - calendar.firstWeekday + 7) % 7

        // Always render 6 weeks (42 cells) so the grid height stays constant.
        let totalCells = 42
        let startDate = calendar.date(byAdding: .day, value: -leadingPad, to: firstOfMonth)!

        return (0..<totalCells).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate)
        }
    }

    // MARK: - Actions

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            withAnimation(.easeInOut(duration: 0.18)) {
                visibleMonth = newMonth
            }
        }
    }
}

#Preview {
    ArchiveCalendarView(
        selection: .constant(Date()),
        availableDateStrings: Set(
            (0..<20).compactMap { offset in
                Calendar.current.date(byAdding: .day, value: -offset * 2, to: Date())
            }
            .map(ArchiveCalendarView.dateString(from:))
        )
    )
    .frame(width: 340)
    .padding()
    .preferredColorScheme(.dark)
}
