import SwiftUI
import SwiftData

/// Daily Minute spine: the existing calendar, restyled onto ink.
struct CourseMinuteSpine: View {
    @Binding var path: NavigationPath

    @Query(
        filter: #Predicate<ArchivedReading> { $0.channel == "daily-minute" },
        sort: \ArchivedReading.dateString
    )
    private var archivedMinutes: [ArchivedReading]
    @Query private var storedMinutes: [DailyMinute]

    @State private var calendar = ArchiveCalendarState.starting(now: Date())
    @State private var searchText: String = ""

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if trimmedQuery.isEmpty {
                calendarStack
            } else {
                searchResults
            }
        }
        .acimInkBackground()
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: jumpPlacement) {
                Button("Today") {
                    withAnimation {
                        calendar.revealToday(now: Date(), availableDateStrings: minuteDates)
                    }
                }
            }
        }
    }

    private var calendarStack: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CourseSpineMasthead(
                    title: CourseShelf.minute.bookName,
                    sub: "One passage a day, drawn from the Text"
                )
                #if !os(tvOS)
                CourseSearchField(text: $searchText, prompt: "Search past minutes")
                    .padding(.top, 14)
                #endif
                Button {
                    openDay(calendar.selection)
                } label: {
                    HStack {
                        Text(MinuteSchedule.longDateString(from: calendar.selection))
                            .font(.acimRowTitle)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.acimCaption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Metric.row)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 14)

                ArchiveCalendarView(
                    selection: $calendar.selection,
                    visibleMonth: $calendar.visibleMonth,
                    availableDateStrings: minuteDates
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .padding(.horizontal, Metric.gutter)
            .padding(.vertical, 12)
            .readableContentWidth()
        }
        .acimInkBackground()
    }

    private var searchResults: some View {
        let results = filteredMinutes()
        return List {
            #if !os(tvOS)
            CourseSearchField(text: $searchText, prompt: "Search past minutes")
                .listRowInsets(EdgeInsets(top: 12, leading: Metric.gutter, bottom: 8, trailing: Metric.gutter))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            #endif
            if results.isEmpty {
                ContentUnavailableView.search(text: trimmedQuery)
                    #if !os(tvOS)
                    .listRowSeparator(.hidden)
                    #endif
                    .listRowBackground(Color.clear)
            } else {
                ForEach(results, id: \.lineHash) { reading in
                    Button {
                        path.append(MinuteDateRef(dateString: reading.dateString))
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reading.dateString)
                                .font(.acimRowSub)
                                .foregroundStyle(.secondary)
                            Text(snippet(reading.text))
                                .font(.acimRowTitle)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                        }
                        .padding(.vertical, Metric.row)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .readableContentWidth()
        .acimInkListBackground()
    }

    private var minuteDates: Set<String> {
        var dates = Set(archivedMinutes.map(\.dateString).filter { !$0.isEmpty })
        for minute in storedMinutes where !minute.date.isEmpty {
            dates.insert(minute.date)
        }
        return dates
    }

    private func openDay(_ date: Date) {
        let key = MinuteSchedule.utcDateString(from: date)
        path.append(MinuteDateRef(dateString: key))
    }

    private func filteredMinutes() -> [ArchivedReading] {
        let q = trimmedQuery
        if isIsoDate(q) {
            return archivedMinutes.filter { $0.dateString == q }
        }
        return archivedMinutes.filter { $0.searchableText.localizedStandardContains(q) }
    }

    private func isIsoDate(_ s: String) -> Bool {
        guard s.count == 10 else { return false }
        let parts = s.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2 else {
            return false
        }
        return parts.allSatisfy { $0.allSatisfy(\.isNumber) }
    }

    private func snippet(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard collapsed.count > 120 else { return collapsed }
        let idx = collapsed.index(collapsed.startIndex, offsetBy: 120)
        return collapsed[..<idx] + "…"
    }

    private var jumpPlacement: ToolbarItemPlacement {
        #if os(iOS)
        .topBarTrailing
        #elseif os(tvOS)
        .automatic
        #else
        .primaryAction
        #endif
    }
}
