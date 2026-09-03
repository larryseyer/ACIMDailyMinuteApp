import SwiftUI
import SwiftData

/// One thing the reader wrote, in the Saved tab.
struct NoteRow: View {
    let note: Note

    @Query private var media: [SegmentMedia]

    private let key: ReadingKey?

    init(note: Note) {
        self.note = note
        self.key = ReadingKey(rawValue: note.readingKey)
        _media = Query(filter: #Predicate<SegmentMedia> { $0.segmentId > 0 })
    }

    var body: some View {
        if let destination = key?.savedDestination(media: media) {
            NavigationLink(value: destination) { rowContent }
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(Color.acimGold)
                .font(.title3)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(key?.displayName() ?? "Reading")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(note.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(note.body)
                    .font(.acimBody)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
