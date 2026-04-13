import SwiftUI

/// Single episode row inside the Listen tab feed. Whole row is tappable
/// and routes to `AudioManager.play` via the `onTap` closure the parent
/// provides — no environment reads here so the row stays a pure value
/// renderer and SwiftUI can skip it cleanly during list virtualisation.
///
/// When the episode matches the active `AudioManager` title the leading
/// glyph swaps from `play.fill` to `waveform` in the gold accent, giving
/// a now-playing cue without a separate indicator column.
struct PodcastEpisodeRow: View {
    let episode: PodcastEpisode
    let isPlaying: Bool
    let onTap: () -> Void

    private static let accent = Color(red: 0.83, green: 0.69, blue: 0.22)
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                icon
                textColumn
                Spacer(minLength: 8)
                if !episode.duration.isEmpty {
                    durationChip
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.title), \(formattedDate)")
        .accessibilityHint("Plays episode")
    }

    // MARK: - Subviews

    private var icon: some View {
        Image(systemName: isPlaying ? "waveform" : "play.fill")
            .font(.system(size: 22))
            .foregroundStyle(isPlaying ? Self.accent : .primary)
            .frame(width: 30)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: isPlaying)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(episode.title)
                .font(.custom("Georgia", size: 15))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(formattedDate)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var durationChip: some View {
        Text(episode.duration)
            .font(.caption2)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }

    // MARK: - Formatting

    private var formattedDate: String {
        let now = Date()
        let elapsed = now.timeIntervalSince(episode.date)
        let sevenDays: TimeInterval = 60 * 60 * 24 * 7
        if elapsed >= 0 && elapsed < sevenDays {
            return Self.relativeFormatter.localizedString(for: episode.date, relativeTo: now)
        }
        return episode.date.formatted(.dateTime.month().day().year())
    }
}
