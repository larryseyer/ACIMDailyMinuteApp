import Foundation
import AVFoundation
import MediaPlayer

@Observable
@MainActor
final class AudioManager {
    var isPlaying = false
    var currentTitle = ""
    var currentTime: Double = 0
    var duration: Double = 0
    var hasActiveAudio = false

    private var player: AVPlayer?
    private var timeObserver: Any?

    func play(url: String, title: String) {
        stop()

        guard let audioURL = URL(string: url) else { return }

        configureAudioSession()

        let item = AVPlayerItem(url: audioURL)
        player = AVPlayer(playerItem: item)
        currentTitle = title
        hasActiveAudio = true

        setupTimeObserver()
        setupRemoteCommands()

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    func skip(by seconds: Double) {
        guard let player else { return }
        let newTime = CMTime(seconds: currentTime + seconds, preferredTimescale: 600)
        player.seek(to: newTime)
    }

    func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        hasActiveAudio = false
        currentTime = 0
        duration = 0
        currentTitle = ""
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Best effort
        }
        #endif
    }

    // MARK: - Time Observer

    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                if let item = self.player?.currentItem {
                    let dur = item.duration.seconds
                    if dur.isFinite { self.duration = dur }
                }
            }
        }
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: 15) }
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skip(by: -15) }
            return .success
        }
    }

    // MARK: - Now Playing

    private func updateNowPlayingInfo() {
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
