import SwiftUI

/// Single episode row inside the Listen tab feed.
///
/// Audio rows use the same `ListenButton` the Today header does — Listen,
/// then Pause while playing and Play while paused — so the finger that
/// started a Minute or Lesson can halt it without leaving this list.
/// ContentView hides the mini-player overlay on this tab, and a waveform
/// glyph cannot be paused; this is the pause control. The title and
/// listened marker stay a second tap target for the same action, because
/// SwiftUI will not nest a Button inside a Button.
///
/// Video-only rows (no published MP3) keep a whole-row tap that opens the
/// video. There is no in-app pause for that path: YouTube's own chrome
/// takes over once the player is up.
///
/// No environment reads, so the row stays a pure value renderer and
/// SwiftUI can skip it cleanly during list virtualisation.
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
    var isActive: Bool = false
    var isPlaying: Bool = false

    /// When the reader last opened this episode; `nil` if they never have.
    let playedAt: Date?

    let onTap: () -> Void

    private static let accent = Color.acimGold

    var body: some View {
        #if os(tvOS)
        playableRow
        #else
        if opensVideo {
            playableRow
        } else {
            HStack(spacing: 12) {
                ListenButton(
                    title: episode.title,
                    isActive: isActive,
                    isPlaying: isPlaying,
                    action: onTap
                )
                Button(action: onTap) {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint(playPauseHint)
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .contain)
        }
        #endif
    }

    private var playableRow: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                icon
                rowContent
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(opensVideo ? "Opens video" : playPauseHint)
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            textColumn
            Spacer(minLength: 8)
            listenedIndicator
        }
        .contentShape(Rectangle())
    }

    /// True when this episode has no published audio and tapping will open its
    /// video instead — the branch `ListenView.play(_:)` already takes.
    private var opensVideo: Bool {
        episode.audioURL.isEmpty && !episode.youtubeURL.isEmpty
    }

    private var isListened: Bool { playedAt != nil }

    // MARK: - Subviews

    private var icon: some View {
        Image(systemName: glyph)
            .font(.system(size: 22))
            .foregroundStyle(isActive ? Self.accent : .primary)
            .frame(width: 30)
    }

    private var glyph: String {
        if isActive && isPlaying { return "pause.fill" }
        if isActive { return "play.fill" }
        return opensVideo ? "play.rectangle.fill" : "play.fill"
    }

    private var playPauseHint: String {
        if isActive && isPlaying { return "Pauses episode" }
        if isActive { return "Resumes episode" }
        return "Plays episode"
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
