import SwiftUI
#if os(tvOS)
import UIKit

/// What the television plays: the YouTube video, rebuilt in the app.
///
/// ⛔ **Not a file and not a stream.** tvOS has no WebKit, the feed carries no
/// video URL, and hosting MP4s would be a service the app cannot outlive.
/// The three ingredients of the YouTube upload — the art, the passage, the
/// narration — are already here. Composing them is the video.
struct TVPlayerItem: Identifiable, Hashable {
    let id: String
    let eyebrow: String
    let title: String?
    let text: String
    let citation: String?
    let audioURL: String?

    static func minute(_ minute: DailyMinute) -> TVPlayerItem {
        let segment = CorpusService.shared.segment(id: minute.segmentId)
        return TVPlayerItem(
            id: "minute:\(minute.segmentHash)",
            eyebrow: "Daily Minute",
            title: nil,
            text: minute.text,
            citation: segment?.citation,
            audioURL: minute.audioURL
        )
    }

    static func lesson(_ lesson: DailyLesson) -> TVPlayerItem {
        TVPlayerItem(
            id: "lesson:\(lesson.lessonNumber)",
            eyebrow: "Lesson \(lesson.lessonNumber)",
            title: lesson.lessonTitle,
            text: lesson.text,
            citation: nil,
            audioURL: lesson.audioURL
        )
    }

    static func segment(_ segment: CorpusSegment) -> TVPlayerItem {
        TVPlayerItem(
            id: "segment:\(segment.segmentId)",
            eyebrow: segment.bookName,
            title: nil,
            text: segment.body,
            citation: segment.citation,
            audioURL: nil
        )
    }
}

/// The YouTube Daily Minute, drawn live: title card, Ken Burns on the art,
/// then a centered sans-serif crawl over a dark band. Measured against
/// the 2026-09-07 upload (`wzDfH-2oGlQ`).
struct TVPlayerView: View {
    let item: TVPlayerItem

    @Environment(AudioManager.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showTransport = true
    @State private var hideTransportTask: Task<Void, Never>?
    @State private var clock = PlayheadClock()
    @State private var silentOrigin = Date()
    @State private var crawlNudge: CGFloat = 0
    @State private var textHeight: CGFloat = 0

    private var display: String {
        ReadingText.paragraphs(from: item.text).joined(separator: " ")
    }

    private var hasAudio: Bool {
        if let url = item.audioURL, !url.isEmpty { return true }
        return false
    }

    private var wordCount: Int {
        display.split(whereSeparator: \.isWhitespace).count
    }

    /// When the MP3's duration is not in yet, pace the crawl from word count
    /// the way the upload does — about 144 words a minute plus the title card.
    private var totalDuration: Double {
        if hasAudio, audio.duration > 1 { return audio.duration }
        return TVPlayerLayout.intro
            + max(8, Double(wordCount) / TVPlayerLayout.wordsPerSecond)
    }

    private var timelinePaused: Bool {
        hasAudio && !audio.isPlaying
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: timelinePaused
            )
        ) { context in
            playerCanvas(at: context.date)
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onDisappear(perform: stop)
        .onChange(of: audio.isPlaying) { _, playing in
            clock.sync(media: audio.currentTime, playing: playing)
        }
        .onChange(of: audio.currentTime) { _, time in
            let predicted = clock.time(at: .now, duration: totalDuration)
            if abs(time - predicted) > 0.85 {
                clock.sync(media: time, playing: audio.isPlaying)
            }
        }
        .onPlayPauseCommand {
            guard hasAudio else { return }
            audio.togglePlayback()
            revealTransport()
        }
        .onMoveCommand(perform: move)
        .onExitCommand { dismiss() }
    }

    private func playerCanvas(at date: Date) -> some View {
        let media = mediaTime(at: date)
        let duration = totalDuration
        let kenBurns = duration > 0 ? min(1, max(0, media / duration)) : 0
        let captionAge = max(0, media - TVPlayerLayout.intro)
        let captionSpan = max(0.1, duration - TVPlayerLayout.intro)
        let captionProgress = min(1, captionAge / captionSpan)
        let fade = min(1, captionAge / 0.45)

        return GeometryReader { geo in
            ZStack {
                art(progress: kenBurns, size: geo.size)
                if fade > 0 {
                    TVCaptionCrawl(
                        text: display,
                        progress: captionProgress,
                        fade: fade,
                        size: geo.size,
                        nudge: crawlNudge,
                        textHeight: $textHeight
                    )
                }
                VStack {
                    Spacer()
                    transport
                        .padding(.horizontal, 80)
                        .padding(.bottom, 36)
                        .opacity(hasAudio && showTransport ? 1 : 0)
                }
            }
        }
    }

    private func art(progress: Double, size: CGSize) -> some View {
        let zoom: CGFloat = reduceMotion
            ? 1
            : 1 + TVPlayerLayout.kenBurns * progress
        return Image("PlayerArt")
            .resizable()
            .scaledToFill()
            .scaleEffect(zoom, anchor: TVPlayerLayout.kenBurnsAnchor)
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    private var transport: some View {
        HStack(spacing: 24) {
            Button {
                audio.togglePlayback()
                revealTransport()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)

            if audio.duration > 0 {
                let fraction = max(0, min(1, audio.currentTime / audio.duration))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule()
                            .fill(Color.acimGold)
                            .frame(width: g.size.width * fraction)
                    }
                }
                .frame(height: 8)
                Text(timeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()
        }
    }

    private var timeLabel: String {
        func fmt(_ t: Double) -> String {
            let s = max(0, Int(t))
            return String(format: "%d:%02d", s / 60, s % 60)
        }
        return "\(fmt(audio.currentTime)) / \(fmt(audio.duration))"
    }

    private func mediaTime(at date: Date) -> Double {
        if hasAudio {
            return clock.time(at: date, duration: totalDuration)
        }
        return min(date.timeIntervalSince(silentOrigin), totalDuration)
    }

    private func start() {
        if let url = item.audioURL, !url.isEmpty {
            audio.play(url: url, title: item.eyebrow)
            UIApplication.shared.isIdleTimerDisabled = true
            clock.sync(media: 0, playing: true)
        } else {
            silentOrigin = Date()
        }
        revealTransport()
    }

    private func stop() {
        UIApplication.shared.isIdleTimerDisabled = false
        hideTransportTask?.cancel()
        if hasAudio { audio.stop() }
    }

    private func move(_ direction: MoveCommandDirection) {
        switch direction {
        case .left:
            guard hasAudio else { return }
            audio.skip(by: -10)
            revealTransport()
        case .right:
            guard hasAudio else { return }
            audio.skip(by: 10)
            revealTransport()
        case .up:
            crawlNudge += TVPlayerLayout.nudgeStep
        case .down:
            crawlNudge -= TVPlayerLayout.nudgeStep
        default:
            break
        }
    }

    private func revealTransport() {
        showTransport = true
        hideTransportTask?.cancel()
        hideTransportTask = Task {
            try? await Task.sleep(nanoseconds: TVPlayerLayout.transportFadeNanos)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { showTransport = false }
        }
    }
}

/// Constants taken off the 2026-09-07 upload, 105 seconds, 1920×1080.
private enum TVPlayerLayout {
    static let intro: Double = 2.8
    static let wordsPerSecond: Double = 2.4
    static let kenBurns: CGFloat = 0.14
    static let kenBurnsAnchor = UnitPoint(x: 0.47, y: 0.60)
    static let bandOpacity: Double = 0.70
    static let bandHPadFraction: CGFloat = 0.035
    static let textHPadFraction: CGFloat = 0.11
    static let corner: CGFloat = 16
    static let expandUntil: Double = 0.28
    static let outroStart: Double = 0.80
    static let startBand: CGFloat = 0.14
    static let midBand: CGFloat = 0.72
    static let endBand: CGFloat = 0.42
    static let fontFraction: CGFloat = 0.040
    static let lineSpacing: CGFloat = 10
    static let innerPad: CGFloat = 22
    static let nudgeStep: CGFloat = 80
    static let transportFadeNanos: UInt64 = 4_000_000_000
}

/// Dark rounded band with a credits-style crawl through it.
private struct TVCaptionCrawl: View {
    let text: String
    let progress: Double
    let fade: Double
    let size: CGSize
    let nudge: CGFloat
    @Binding var textHeight: CGFloat

    var body: some View {
        let band = Self.band(progress: progress, size: size)
        let textWidth = size.width * (1 - TVPlayerLayout.textHPadFraction * 2)
        let fontSize = max(30, size.height * TVPlayerLayout.fontFraction)

        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: TVPlayerLayout.corner, style: .continuous)
                .fill(.black.opacity(TVPlayerLayout.bandOpacity))

            Text(text)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(TVPlayerLayout.lineSpacing)
                .frame(width: textWidth, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { g in
                        Color.clear.preference(
                            key: TVCrawlHeightKey.self,
                            value: g.size.height
                        )
                    }
                }
                .offset(y: Self.crawlY(
                    progress: progress,
                    bandHeight: band.height,
                    textHeight: textHeight
                ) + nudge)
        }
        .frame(
            width: size.width * (1 - TVPlayerLayout.bandHPadFraction * 2),
            height: band.height,
            alignment: .top
        )
        .clipped()
        .opacity(textHeight > 0 ? fade : 0)
        .position(x: size.width / 2, y: band.midY)
        .onPreferenceChange(TVCrawlHeightKey.self) { textHeight = $0 }
    }

    /// Lower-third that grows under the wordmark, then settles upper-mid
    /// at the end so the book and tagline return — the upload's shape.
    static func band(progress: Double, size: CGSize) -> (height: CGFloat, midY: CGFloat) {
        let startH = size.height * TVPlayerLayout.startBand
        let midH = size.height * TVPlayerLayout.midBand
        let endH = size.height * TVPlayerLayout.endBand
        let height: CGFloat
        let top: CGFloat
        if progress < TVPlayerLayout.expandUntil {
            let t = smooth(progress / TVPlayerLayout.expandUntil)
            height = startH + (midH - startH) * t
            top = size.height - height
        } else if progress < TVPlayerLayout.outroStart {
            height = midH
            top = size.height - height
        } else {
            let span = 1 - TVPlayerLayout.outroStart
            let t = smooth((progress - TVPlayerLayout.outroStart) / span)
            height = midH + (endH - midH) * t
            let bottomAligned = size.height - height
            let outroTop = size.height * 0.08
            top = bottomAligned + (outroTop - bottomAligned) * t
        }
        return (height, top + height / 2)
    }

    static func crawlY(progress: Double, bandHeight: CGFloat, textHeight: CGFloat) -> CGFloat {
        let pad = TVPlayerLayout.innerPad
        let inner = max(1, bandHeight - pad * 2)
        let topAligned = pad
        // While the band is growing, pin the passage to its top so the
        // first lines stay put and more of them appear underneath — the
        // upload's lower-third. Crawl only after the band has opened.
        if progress < TVPlayerLayout.expandUntil || textHeight <= inner * 0.95 {
            return topAligned
        }
        let crawlT = (progress - TVPlayerLayout.expandUntil)
            / (1 - TVPlayerLayout.expandUntil)
        let end = pad + inner * 0.40 - textHeight
        return topAligned + (end - topAligned) * crawlT
    }

    static func smooth(_ t: Double) -> CGFloat {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }
}

/// Interpolates between the audio observer's 0.5s ticks so the crawl does
/// not stutter. Resyncs on play/pause and on a seek larger than a tick.
private struct PlayheadClock {
    var originMedia: Double = 0
    var originWall: Date = .now
    var playing = false

    func time(at date: Date, duration: Double) -> Double {
        let raw = playing
            ? originMedia + date.timeIntervalSince(originWall)
            : originMedia
        if duration > 0 { return min(max(0, raw), duration) }
        return max(0, raw)
    }

    mutating func sync(media: Double, playing: Bool, at date: Date = .now) {
        originMedia = media
        originWall = date
        self.playing = playing
    }
}

private struct TVCrawlHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
#endif
