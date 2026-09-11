import SwiftUI

/// Compact Now Playing bar. Sits 8pt above `ACIMTabBar`.
///
/// `height` is 56pt of bar plus the 8pt gap, so surfaces that already
/// reserve this symbol keep a correct last-line clearance.
struct MiniPlayerView: View {
    public static let height: CGFloat = 64

    @Environment(AudioManager.self) private var audioManager
    @Environment(\.openNowPlaying) private var openNowPlaying

    var body: some View {
        HStack(spacing: 10) {
            Button {
                openNowPlaying()
            } label: {
                HStack(spacing: 10) {
                    art
                    VStack(alignment: .leading, spacing: 1) {
                        Text(audioManager.currentTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the full player")
            Button {
                audioManager.togglePlayback()
            } label: {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Play")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 56)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(Color.acimSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.acimHairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(audioManager.currentTitle)")
    }

    private var art: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.acimRaised)
            .overlay {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.acimGold)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.acimRule, lineWidth: 1)
            }
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)
    }

    private var subtitle: String {
        if audioManager.duration > 0 {
            return AudioTransport.remainingLabel(
                position: audioManager.currentTime,
                duration: audioManager.duration
            )
        }
        return "Now playing"
    }
}

struct OpenNowPlayingAction: Sendable {
    private let handler: @Sendable () -> Void

    init(handler: @escaping @Sendable () -> Void) {
        self.handler = handler
    }

    func callAsFunction() { handler() }
}

private struct OpenNowPlayingKey: EnvironmentKey {
    static let defaultValue = OpenNowPlayingAction { }
}

extension EnvironmentValues {
    var openNowPlaying: OpenNowPlayingAction {
        get { self[OpenNowPlayingKey.self] }
        set { self[OpenNowPlayingKey.self] = newValue }
    }
}
