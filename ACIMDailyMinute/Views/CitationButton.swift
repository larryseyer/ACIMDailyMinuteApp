import SwiftUI

/// A card's citation footer, which answers a tap when the address names a
/// place the bundle holds and prints quietly when it does not.
///
/// Both Today cards draw their footer through this one view, so the card that
/// comes from the feed and its offline twin cannot disagree about what an
/// address does. Book names — the Manual, an archived row with no segment —
/// are not addresses and never become buttons.
struct CitationButton: View {
    let citation: String?
    let bookName: String

    @Environment(\.openReading) private var openReading

    private var destination: (label: String, target: ReadingDestination)? {
        guard let citation,
              let parsed = Citation(rawValue: citation),
              let target = CitationResolver.destination(for: parsed)
        else { return nil }
        return (citation, target)
    }

    var body: some View {
        if let destination {
            Button {
                openReading(destination.target)
            } label: {
                Text(destination.label)
                    .font(.footnote.italic())
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(destination.label) in the Course")
        } else {
            Text(citation ?? bookName)
                .font(.footnote.italic())
                .foregroundStyle(.secondary)
        }
    }
}
