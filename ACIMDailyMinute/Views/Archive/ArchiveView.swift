import SwiftUI

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedDate = Date()
    @State private var availableDates: [String] = []
    @State private var dayStories: [ArchivedStory] = []
    @State private var isLoadingIndex = true
    @State private var isLoadingDay = false
    @State private var errorMessage: String?
    @State private var showSearch = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                #if os(macOS)
                MacCalendarView(selection: $selectedDate)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                #else
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                #endif

                Divider()

                contentArea
            }
            .navigationTitle("Archive")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Today") {
                        selectedDate = Date()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .navigationDestination(isPresented: $showSearch) {
                ArchiveSearchView()
            }
            .task {
                await loadIndex()
                await loadDay()
            }
            .onChange(of: selectedDate) {
                Task { await loadDay() }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if isLoadingDay {
            ProgressView("Loading archive...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.acimTitle)
                    .foregroundStyle(.secondary)
                Text(errorMessage)
                    .font(.acimSubheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !dayStories.isEmpty {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(dayStories, id: \.lineHash) { story in
                        archivedStoryCard(story)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "archivebox")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Select a date to view archived stories")
                    .font(.acimSubheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Archived Story Card

    private func archivedStoryCard(_ story: ArchivedStory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Fact text
            Text(story.factText)
                .font(.acimBody)
                .fixedSize(horizontal: false, vertical: true)

            // Sources with ratings
            if !story.sources.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(zip(story.sources, story.ratings).enumerated()), id: \.offset) { _, pair in
                        HStack(spacing: 4) {
                            Text(pair.0)
                                .font(.acimCaption)
                                .foregroundStyle(.primary.opacity(0.8))
                            if let ratingValue = pair.1.components(separatedBy: " ").first {
                                Text(ratingValue)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(white: 0.17).opacity(0.5))
                        .clipShape(Capsule())
                    }
                }
            }

            // Bottom row: time + correction indicator
            HStack {
                if let timestamp = story.timestamp {
                    Text(timestamp, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if story.isCorrected {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Corrected")
                            .font(.caption2)
                    }
                    .foregroundStyle(.orange.opacity(0.8))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private static func midnightGMTInLocalTime() -> String {
        var components = Calendar.current.dateComponents(in: TimeZone(identifier: "GMT")!, from: Date())
        components.day! += 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        let midnightGMT = Calendar.current.date(from: components)!

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = .current
        return formatter.string(from: midnightGMT)
    }

    // MARK: - Load

    private func loadIndex() async {
        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            availableDates = try await service.fetchIndex()
        } catch {
            // Graceful degradation
        }
        isLoadingIndex = false
    }

    private func loadDay() async {
        let dateString = dateFormatter.string(from: selectedDate)
        isLoadingDay = true
        errorMessage = nil
        dayStories = []

        let service = ArchiveService(modelContainer: modelContext.container)
        do {
            dayStories = try await service.fetchDay(dateString: dateString)
        } catch {
            if Calendar.current.isDateInToday(selectedDate) {
                let localTime = Self.midnightGMTInLocalTime()
                errorMessage = "Today's archive will be available at \(localTime)"
            } else {
                errorMessage = "Archive not available for \(dateString)"
            }
        }
        isLoadingDay = false
    }
}

#Preview {
    ArchiveView()
        .preferredColorScheme(.dark)
}
