import SwiftUI
import AVFoundation

struct AudioPlayerView: View {
    let audioURL: String
    let title: String
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.acimSubheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Progress
            VStack(spacing: 4) {
                ProgressView(value: duration > 0 ? currentTime / duration : 0)
                    .tint(.blue)

                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTime(duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Controls
            HStack(spacing: 32) {
                Button {
                    skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                }
                .accessibilityLabel("Skip back 15 seconds")

                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 48))
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Button {
                    skip(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                }
                .accessibilityLabel("Skip forward 15 seconds")
            }
            .foregroundStyle(.primary)
        }
        .padding(20)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { setupPlayer() }
        .onDisappear { cleanup() }
    }

    private func setupPlayer() {
        guard let url = URL(string: audioURL) else { return }
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak player] time in
            MainActor.assumeIsolated {
                self.currentTime = time.seconds
                if let item = player?.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite { self.duration = dur }
                }
            }
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func skip(by seconds: Double) {
        guard let player else { return }
        let newTime = CMTime(seconds: currentTime + seconds, preferredTimescale: 600)
        player.seek(to: newTime)
    }

    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
