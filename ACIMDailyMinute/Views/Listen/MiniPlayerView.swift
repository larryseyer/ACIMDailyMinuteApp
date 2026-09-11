import SwiftUI

/// The one in-app player. Today, Listen, and Saved draw this bar; Read
/// does not — that tab is the words, and a leftover Today session must
/// not sit on them. Seek, skip, pause, and close all live here so every
/// surface that plays audio has the same control.
struct MiniPlayerView: View {
    public static let height: CGFloat = 120

    @Environment(AudioManager.self) private var audioManager
    @State private var isScrubbing = false
    @State private var scrubPosition: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            titleRow
            scrubber
            transport
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: Self.height)
        .background(.ultraThinMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(audioManager.currentTitle)")
        .onAppear { scrubPosition = audioManager.currentTime }
        .onChange(of: audioManager.currentTime) { _, time in
            if !isScrubbing { scrubPosition = time }
        }
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(Color.acimGold)
                .accessibilityHidden(true)

            Text(audioManager.currentTitle)
                .font(.acimCaption)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                audioManager.stop()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close player")
        }
    }

    private var scrubber: some View {
        HStack(spacing: 8) {
            Text(AudioTransport.timeLabel(displayedTime))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 36, alignment: .leading)

            #if os(tvOS)
            ProgressView(value: displayedTime, total: max(sliderMax, 0.001))
                .tint(Color.acimGold)
            #else
            Slider(
                value: $scrubPosition,
                in: 0...sliderMax,
                onEditingChanged: scrubChanged
            )
            .tint(Color.acimGold)
            .disabled(audioManager.duration <= 0)
            .accessibilityLabel("Playback position")
            .accessibilityValue(AudioTransport.timeLabel(displayedTime))
            #endif

            Text(AudioTransport.remainingLabel(position: displayedTime, duration: audioManager.duration))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 42, alignment: .trailing)
        }
    }

    private var transport: some View {
        HStack(spacing: 28) {
            Button {
                audioManager.skip(by: -15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip back 15 seconds")

            Button {
                audioManager.togglePlayback()
            } label: {
                Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .accessibilityLabel(audioManager.isPlaying ? "Pause" : "Play")

            Button {
                audioManager.skip(by: 15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip forward 15 seconds")
        }
        .frame(maxWidth: .infinity)
    }

    private var displayedTime: Double {
        isScrubbing ? scrubPosition : audioManager.currentTime
    }

    private var sliderMax: Double {
        max(audioManager.duration, 0.001)
    }

    private func scrubChanged(_ editing: Bool) {
        if editing {
            isScrubbing = true
            return
        }
        audioManager.seek(to: scrubPosition)
        isScrubbing = false
    }
}
