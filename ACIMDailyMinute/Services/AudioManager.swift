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
    var lastError: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?

    func play(url: String, title: String) {
        stop()
        lastError = nil

        guard let audioURL = URL(string: Self.resolve(url)) else { return }

        #if os(iOS) || os(watchOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
        } catch {
            lastError = "Audio session error: \(error.localizedDescription)"
            return
        }
        #endif

        let item = AVPlayerItem(url: audioURL)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch playerItem.status {
                case .failed:
                    self.lastError = playerItem.error?.localizedDescription ?? "Audio failed to load"
                case .readyToPlay:
                    self.lastError = nil
                default:
                    break
                }
            }
        }
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
        statusObservation?.invalidate()
        statusObservation = nil
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

    // MARK: - URL Resolution

    /// The ACIM publisher emits relative `audio_url` paths
    /// (e.g. `/audio/2026-04-13.mp3`) inside the JSON and podcast feeds.
    /// `AVPlayer` requires absolute URLs, so prepend the canonical host
    /// when the input lacks a scheme. Already-absolute URLs (podcast
    /// enclosure URLs that point to a CDN, manually-pasted external
    /// links) pass through unchanged.
    static func resolve(_ url: String) -> String {
        if url.hasPrefix("http://") || url.hasPrefix("https://") { return url }
        let host = "https://www.acimdailyminute.org"
        return url.hasPrefix("/") ? "\(host)\(url)" : "\(host)/\(url)"
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
