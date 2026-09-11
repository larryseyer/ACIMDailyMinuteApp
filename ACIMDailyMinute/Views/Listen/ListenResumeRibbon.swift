import SwiftUI

/// Now Playing, or Continue, above the Listen shelf.
///
/// Activity is chrome, not the tab. Nothing appears when there is no
/// session and nothing part-finished — a ribbon that says "nothing to
/// resume" is the empty state this view exists to retire.
struct ListenResumeRibbon: View {
    let item: ListenLibrary.Resume
    var isActive: Bool
    var isPlaying: Bool
    let onTap: () -> Void

    private var caption: String {
        switch item.kind {
        case .nowPlaying: "Now Playing"
        case .continue: "Continue"
        }
    }

    var body: some View {
        #if os(tvOS)
        Button(action: onTap) {
            HStack(spacing: 12) {
                captionAndTitle
                Spacer(minLength: 8)
            }
            .padding(14)
            .background(Color.acimCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(caption), \(item.title)")
        .accessibilityHint(isActive && isPlaying ? "Pauses episode" : "Plays episode")
        #else
        HStack(spacing: 12) {
            ListenButton(
                title: item.title,
                isActive: isActive,
                isPlaying: isPlaying,
                action: onTap
            )
            Button(action: onTap) {
                HStack {
                    captionAndTitle
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.acimCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(caption), \(item.title)")
        #endif
    }

    private var captionAndTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.title)
                .font(.system(.subheadline, design: .serif).weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
