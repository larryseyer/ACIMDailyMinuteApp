import Foundation
import AVFoundation
import MediaPlayer

@Observable
@MainActor
final class AudioManager {
    var isPlaying = false
    var currentTitle = ""
    /// The resolved URL of the item in the mini player. Header Listen buttons
    /// match on this, not on `currentTitle`: every Daily Minute is titled
    /// "Daily Minute", and a title match would paint Pause on a different day's
    /// card.
    var currentURL = ""
    /// The Listen identity of the item in the mini player: the feed episode id
    /// when the caller has one, otherwise the resolved remote URL. Empty when
    /// a file:// URL was played with no episode id — that session cannot be
    /// found again, so it is not recorded.
    var currentEpisodeID = ""
    var currentTime: Double = 0
    var duration: Double = 0
    var hasActiveAudio = false
    var lastError: String?
    /// True after the current item plays through to its end. Cleared on the
    /// next `play` or `stop`. The television player uses this to leave the
    /// finished frame instead of sitting on it.
    var didFinishPlayback = false

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    /// Seconds to seek once the item is ready, taken from stored progress.
    /// Nil means start at the beginning.
    private var pendingSeek: Double?
    /// Last `currentTime` written to `PlaybackProgressStore`. The time observer
    /// fires twice a second; the store is not a telemetry log.
    private var lastPersistedTime: Double = -1

    func play(url: String, title: String, episodeID: String = "") {
        stop()
        lastError = nil

        let resolved = Self.resolve(url)
        guard let audioURL = URL(string: resolved) else { return }

        #if os(iOS) || os(watchOS) || os(tvOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
        } catch {
            lastError = "Audio session error: \(error.localizedDescription)"
            return
        }
        #endif

        let identity = Self.identity(episodeID: episodeID, resolvedURL: resolved)
        currentEpisodeID = identity
        pendingSeek = Self.resumePosition(for: identity, resolvedURL: resolved)

        let item = AVPlayerItem(url: audioURL)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch playerItem.status {
                case .failed:
                    // Tear the session down before surfacing the error: without
                    // this the mini player stays on screen showing a pause
                    // button for audio that never started.
                    let message = Self.loadFailureMessage(for: playerItem)
                    self.stop()
                    self.lastError = message
                case .readyToPlay:
                    self.lastError = nil
                    self.seekIfNeeded()
                default:
                    break
                }
            }
        }
        player = AVPlayer(playerItem: item)
        currentTitle = title
        currentURL = resolved
        hasActiveAudio = true
        didFinishPlayback = false
        observeEnd(of: item)

        setupTimeObserver()
        setupRemoteCommands()

        // A resume waits for readyToPlay so the seek is not a no-op on an
        // empty item. Starting from the beginning plays immediately, as before.
        if pendingSeek == nil {
            player?.play()
        }
        isPlaying = true
        updateNowPlayingInfo()
    }

    /// True while the mini player is showing this reading, including paused
    /// and finished-but-not-dismissed. Relative and absolute forms of the
    /// same path compare equal through `resolve`.
    func isActive(url: String) -> Bool {
        hasActiveAudio && currentURL == Self.resolve(url)
    }

    /// Header Listen/Pause/Play: start this reading, or toggle pause/resume
    /// if it already owns the mini player — the same job as the mini player's
    /// play/pause control.
    func playOrToggle(url: String, title: String, episodeID: String = "") {
        if isActive(url: url) {
            togglePlayback()
        } else {
            play(url: url, title: title, episodeID: episodeID)
        }
    }

    /// The Text is a different book and has no audio of its own. Arriving on
    /// a chapter or section must drop a Workbook lesson (or Daily Minute)
    /// still in the mini player, or that session sits under the page.
    func dismissForTextReading() {
        guard hasActiveAudio else { return }
        stop()
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            persistProgress()
        } else {
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }

    /// Writes the current place if this session has an identity. Safe to call
    /// from a scene-phase change; a session with no identity is a no-op, which
    /// is what lets the listen-session harness call `stop()` without touching
    /// `UserDefaults`.
    func persistProgress() {
        persistProgress(force: true)
    }

    func skip(by seconds: Double) {
        seek(to: currentTime + seconds)
    }

    /// Move to an absolute place in the current file. The slider, skip
    /// buttons, and lock-screen scrub all go through here so a drag past
    /// the end is the end, never a NaN the player would ignore.
    func seek(to seconds: Double) {
        guard let player else { return }
        let clamped = AudioTransport.clampedPosition(seconds, duration: duration)
        currentTime = clamped
        let time = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateNowPlayingInfo()
                self.persistProgress()
            }
        }
        updateNowPlayingInfo()
    }

    func stop() {
        persistProgress()
        statusObservation?.invalidate()
        statusObservation = nil
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        hasActiveAudio = false
        didFinishPlayback = false
        currentTime = 0
        duration = 0
        currentTitle = ""
        currentURL = ""
        currentEpisodeID = ""
        pendingSeek = nil
        lastPersistedTime = -1
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func observeEnd(of item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                self.didFinishPlayback = true
                if self.duration > 0 {
                    self.currentTime = self.duration
                }
                self.persistProgress()
                self.updateNowPlayingInfo()
            }
        }
    }

    // MARK: - Failure Reporting

    /// AVFoundation hands back the origin server's response body as the
    /// error's `localizedDescription` — a reader tapping Listen was being
    /// shown "The requested URL was not found on this server." Read the HTTP
    /// status off the item's error log instead and say what it means for them.
    private static func loadFailureMessage(for item: AVPlayerItem) -> String {
        switch item.errorLog()?.events.last?.errorStatusCode {
        case 403, 404, 410:
            return "Audio for this reading hasn't been published yet."
        default:
            return "Audio couldn't be loaded. Check your connection and try again."
        }
    }

    // MARK: - URL Resolution

    /// The ACIM publisher emits relative `audio_url` paths
    /// (e.g. `/audio/2026-04-13.mp3`) inside the JSON and podcast feeds.
    /// `AVPlayer` requires absolute URLs, so prepend the canonical host
    /// when the input lacks a scheme. Already-absolute URLs (podcast
    /// enclosure URLs that point to a CDN, manually-pasted external
    /// links) pass through unchanged.
    /// `nonisolated`: pure string work with no player state, and the download
    /// store resolves URLs off the main actor.
    nonisolated static func resolve(_ url: String) -> String {
        if url.hasPrefix("http://") || url.hasPrefix("https://") { return url }
        // A downloaded reading is played from disk. Without this it would be
        // treated as a site-relative feed path and rewritten into a URL on
        // acimdailyminute.org, which is exactly the host the download exists
        // to stop depending on.
        if url.hasPrefix("file://") { return url }
        let host = "https://www.acimdailyminute.org"
        return url.hasPrefix("/") ? "\(host)\(url)" : "\(host)/\(url)"
    }

    /// The key `PlaybackProgressStore` writes. An episode id is stable across
    /// CDN changes; a file:// URL is not a key, because the same recording
    /// streamed remotely would then be a different place.
    nonisolated static func identity(episodeID: String, resolvedURL: String) -> String {
        let trimmed = episodeID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if resolvedURL.hasPrefix("file://") { return "" }
        return resolvedURL
    }

    private static func resumePosition(for identity: String, resolvedURL: String) -> Double? {
        if !identity.isEmpty,
           let resume = PlaybackProgress.resumePosition(PlaybackProgressStore.progress(for: identity)) {
            return resume
        }
        if !resolvedURL.hasPrefix("file://"), resolvedURL != identity,
           let resume = PlaybackProgress.resumePosition(PlaybackProgressStore.progress(for: resolvedURL)) {
            return resume
        }
        return nil
    }

    private func seekIfNeeded() {
        guard let seek = pendingSeek else { return }
        pendingSeek = nil
        let time = CMTime(seconds: seek, preferredTimescale: 600)
        player?.seek(to: time) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isPlaying { self.player?.play() }
                self.updateNowPlayingInfo()
            }
        }
    }

    private func persistProgress(force: Bool) {
        guard !currentEpisodeID.isEmpty else { return }
        guard currentTime.isFinite else { return }
        let length = duration.isFinite ? duration : 0
        let position = didFinishPlayback && length > 0 ? length : currentTime
        // A failed load, or a tap that never got a second in, is not a place.
        if !didFinishPlayback, position < PlaybackProgress.startedThreshold { return }
        if !force, abs(position - lastPersistedTime) < 5 { return }
        guard let progress = PlaybackProgress.make(
            episodeID: currentEpisodeID,
            position: position,
            duration: length,
            at: Date()
        ) else { return }
        lastPersistedTime = position
        PlaybackProgressStore.record(progress)
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
                self.persistProgress(force: false)
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

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.seek(to: event.positionTime) }
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
