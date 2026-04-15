import SwiftUI

struct MiniPlayerView: View {
    public static let height: CGFloat = 56

    @Environment(AudioManager.self) private var audioManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.blue)

            Text(audioManager.currentTitle)
                .font(.acimCaption)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            // Progress indicator
            if audioManager.duration > 0 {
                ProgressView(value: audioManager.currentTime / audioManager.duration)
                    .frame(width: 40)
                    .tint(.blue)
            }

            Button {
                audioManager.togglePlayback()
            } label: {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.acimBody)
            }
            .foregroundStyle(.primary)
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Play")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(audioManager.currentTitle)")
        .accessibilityHint("Tap to open digest")
    }
}
