#if os(macOS)
import SwiftUI

/// iOS-style calendar for macOS. Matches the look of SwiftUI's graphical DatePicker on iOS,
/// which macOS renders via NSDatePicker (a compact native control that doesn't match the iOS UI).
struct MacCalendarView: View {
    @Binding var selection: Date

    @State private var visibleMonth: Date

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 1 // Sunday
        return c
    }()

    init(selection: Binding<Date>) {
        self._selection = selection
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
        let day = calendar.component(.day, from: date)

        Button {
            selection = date
        } label: {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                } else if isToday {
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 1.5)
                }
                Text("\(day)")
                    .font(.system(size: 17, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(foregroundColor(selected: isSelected, today: isToday, inMonth: isInCurrentMonth))
            }
            .frame(width: 40, height: 40)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isInCurrentMonth ? 1.0 : 0.35)
    }

    private func foregroundColor(selected: Bool, today: Bool, inMonth: Bool) -> Color {
        if selected { return .white }
        if today { return .accentColor }
        return .primary
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
    MacCalendarView(selection: .constant(Date()))
        .frame(width: 340)
        .padding()
        .preferredColorScheme(.dark)
}
#endif
