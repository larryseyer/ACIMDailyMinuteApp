import SwiftUI

/// One Listen catalogue row.
///
/// Play is overlay. No enclosure means no `ListenButton` and no row tap
/// that starts audio. The title still draws. There is no YouTube fallback:
/// that is the Video tab.
struct ListenPlayableRow: View {
    let row: ListenLibrary.Row
    var isActive: Bool = false
    var isPlaying: Bool = false
    var playedAt: Date? = nil
    let onTap: () -> Void

    private var canPlay: Bool { ListenLibrary.showsPlay(audioURL: row.audioURL) }

    var body: some View {
        Group {
            if canPlay {
                playable
            } else {
                HStack(spacing: 12) {
                    rowContent
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
            }
        }
    }

    @ViewBuilder
    private var playable: some View {
        #if os(tvOS)
        Button(action: onTap) {
            HStack(spacing: 12) { rowContent }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(playPauseHint)
        #else
        HStack(spacing: 12) {
            ListenButton(
                title: row.title,
                isActive: isActive,
                isPlaying: isPlaying,
                action: onTap
            )
            Button(action: onTap) { rowContent }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(playPauseHint)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        #endif
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Text(row.title)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Image(systemName: playedAt == nil ? "circle" : "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(playedAt == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.acimGold))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
    }

    private var playPauseHint: String {
        if isActive && isPlaying { return "Pauses episode" }
        if isActive { return "Resumes episode" }
        return "Plays episode"
    }

    private var accessibilityLabel: String {
        var parts = [row.title]
        if let playedAt {
            parts.append("Listened")
            parts.append(Self.listenedFormatter.string(from: playedAt))
        } else {
            parts.append("Not listened")
        }
        if !canPlay { parts.append("No audio") }
        return parts.joined(separator: ", ")
    }

    private static let listenedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
