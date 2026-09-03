import SwiftUI

/// Single episode row inside the Listen tab feed. Whole row is tappable
/// and routes to `AudioManager.play` via the `onTap` closure the parent
/// provides — no environment reads here so the row stays a pure value
/// renderer and SwiftUI can skip it cleanly during list virtualisation.
///
/// When the episode matches the active `AudioManager` title the leading
/// glyph swaps from `play.fill` to `waveform` in the gold accent, giving
/// a now-playing cue without a separate indicator column.
///
/// The trailing column is a listened marker rather than a duration. Every Daily
/// Minute runs the same minute, so printing `01:00` on all of them said nothing;
/// for lessons the running time moved under the title, where it varies and is
/// worth reading.
///
/// The only date a row ever shows is when the *reader* listened. When an episode
/// was published is the app's own bookkeeping — it tells the reader nothing, and
/// stamping a year beside every reading ages the list badly.
struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    let feed: PodcastFeed
    let isPlaying: Bool

    /// When the reader last opened this episode; `nil` if they never have.
    let playedAt: Date?

    let onTap: () -> Void

    private static let accent = Color.acimGold

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                icon
                textColumn
                Spacer(minLength: 8)
                listenedIndicator
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(opensVideo ? "Opens video" : "Plays episode")
    }

    /// True when this episode has no published audio and tapping will open its
    /// video instead — the branch `ListenView.play(_:)` already takes. Until
    /// audio hosting is unblocked that is every episode, so the row must not
    /// keep showing a play glyph and promising a listen it cannot deliver.
    private var opensVideo: Bool {
        episode.audioURL.isEmpty && !episode.youtubeURL.isEmpty
    }

    private var isListened: Bool { playedAt != nil }

    // MARK: - Subviews

    private var icon: some View {
        Image(systemName: glyph)
            .font(.system(size: 22))
            .foregroundStyle(isPlaying ? Self.accent : .primary)
            .frame(width: 30)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPlaying)
    }

    private var glyph: String {
        if isPlaying { return "waveform" }
        return opensVideo ? "play.rectangle.fill" : "play.fill"
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(episode.title)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                // Lessons vary in length, so the running time earns its place
                // here. Minutes do not — they are all a minute.
                if feed == .lesson, !episode.duration.isEmpty {
                    Text(episode.duration)
                        .monospacedDigit()
                    if subtitle != nil { Text("·") }
                }
                if let subtitle {
                    Text(subtitle)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var listenedIndicator: some View {
        Image(systemName: isListened ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18))
            .foregroundStyle(isListened ? AnyShapeStyle(Self.accent) : AnyShapeStyle(.tertiary))
            .accessibilityHidden(true)
    }

    // MARK: - Formatting

    private static let listenedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Only ever "when you listened". An unplayed row shows no date at all
    /// rather than falling back to the publication date.
    private var subtitle: String? {
        guard let playedAt else { return nil }
        return "Listened \(Self.listenedFormatter.string(from: playedAt))"
    }

    private var accessibilityLabel: String {
        var parts = [episode.title]
        if feed == .lesson, !episode.duration.isEmpty { parts.append(episode.duration) }
        if let subtitle { parts.append(subtitle) } else { parts.append("Not listened") }
        return parts.joined(separator: ", ")
    }
}
