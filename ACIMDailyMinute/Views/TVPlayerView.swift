import SwiftUI
#if os(tvOS)
import UIKit

/// What the television plays: the YouTube video, rebuilt in the app.
///
/// ⛔ **Not a file and not a stream.** tvOS has no WebKit, the feed carries no
/// video URL, and hosting MP4s would be a service the app cannot outlive.
/// The three ingredients of the YouTube upload — the art, the passage, the
/// narration — are already here. Composing them is the video.
///
/// The composition is `video_builder.py` in the daily pipeline
/// (`acim-daily-minute`), drawn live at 4K instead of muxed into an MP4.
struct TVPlayerItem: Identifiable, Hashable, Sendable {
    let id: String
    let eyebrow: String
    let title: String?
    let text: String
    let citation: String?
    let audioURL: String?
    let artName: String

    static func minute(_ minute: DailyMinute) -> TVPlayerItem {
        let segment = CorpusService.shared.segment(id: minute.segmentId)
        return TVPlayerItem(
            id: "minute:\(minute.segmentHash)",
            eyebrow: "Daily Minute",
            title: nil,
            text: minute.text,
            citation: segment?.citation,
            audioURL: minute.audioURL,
            artName: "PlayerArt"
        )
    }

    static func lesson(_ lesson: DailyLesson) -> TVPlayerItem {
        TVPlayerItem(
            id: "lesson:\(lesson.lessonNumber)",
            eyebrow: "Lesson \(lesson.lessonNumber)",
            title: lesson.lessonTitle,
            text: lesson.text,
            citation: nil,
            audioURL: lesson.audioURL,
            artName: "PlayerArtLesson"
        )
    }

    static func segment(_ segment: CorpusSegment) -> TVPlayerItem {
        TVPlayerItem(
            id: "segment:\(segment.segmentId)",
            eyebrow: segment.bookName,
            title: nil,
            text: segment.body,
            citation: segment.citation,
            audioURL: nil,
            artName: Self.artName(for: segment.sourcePDF)
        )
    }

    /// Archive lesson rows store the title in `text` and no body. The crawl
    /// needs the passage, so the bundled Workbook body fills that hole.
    static func archived(_ reading: ArchivedReading) -> TVPlayerItem {
        if reading.channel == "daily-minute" {
            return TVPlayerItem(
                id: "archive-minute:\(reading.lineHash)",
                eyebrow: "Daily Minute",
                title: nil,
                text: reading.text,
                citation: nil,
                audioURL: reading.audioURL,
                artName: "PlayerArt"
            )
        }
        let number = reading.lessonNumber ?? 0
        let intro = WorkbookBodiesCatalog.introduction(for: number)
        let title = reading.text.isEmpty
            ? (intro?.title ?? WorkbookCatalog.title(for: number))
            : reading.text
        let body = WorkbookBodiesCatalog.body(for: number)
            ?? intro?.body
            ?? title
            ?? ""
        return TVPlayerItem(
            id: "archive-lesson:\(number)",
            eyebrow: (number == 0 || number == 500) ? "Introduction" : "Lesson \(number)",
            title: title,
            text: body,
            citation: nil,
            audioURL: reading.audioURL,
            artName: "PlayerArtLesson"
        )
    }

    static func workbookLesson(_ number: Int, audioURL: String? = nil) -> TVPlayerItem {
        if let intro = WorkbookBodiesCatalog.introduction(for: number) {
            return TVPlayerItem(
                id: "intro:\(number)",
                eyebrow: "Introduction",
                title: intro.title,
                text: intro.body,
                citation: nil,
                audioURL: audioURL,
                artName: "PlayerArtLesson"
            )
        }
        let title = WorkbookCatalog.title(for: number)
        let body = WorkbookBodiesCatalog.body(for: number) ?? title ?? "Lesson \(number)"
        return TVPlayerItem(
            id: "lesson:\(number)",
            eyebrow: "Lesson \(number)",
            title: title,
            text: body,
            citation: nil,
            audioURL: audioURL,
            artName: "PlayerArtLesson"
        )
    }

    static func textSection(chapter: Int, section: Int) -> TVPlayerItem {
        guard let reading = CorpusService.shared.textSection(chapter: chapter, section: section) else {
            return TVPlayerItem(
                id: "text:\(chapter).\(section)",
                eyebrow: "Text",
                title: nil,
                text: "",
                citation: nil,
                audioURL: nil,
                artName: "PlayerArtText"
            )
        }
        return TVPlayerItem(
            id: "text:\(chapter).\(section)",
            eyebrow: chapter == 0 ? "Preface" : "Chapter \(chapter)",
            title: reading.sectionTitle,
            text: reading.body,
            citation: nil,
            audioURL: nil,
            artName: "PlayerArtText"
        )
    }

    static func manual(_ segmentId: Int) -> TVPlayerItem {
        let reading = CorpusService.shared.manualSegment(id: segmentId)
        return TVPlayerItem(
            id: "manual:\(segmentId)",
            eyebrow: "Manual for Teachers",
            title: nil,
            text: reading?.body ?? "",
            citation: reading?.citation,
            audioURL: nil,
            artName: "PlayerArtText"
        )
    }

    func withAudioURL(_ url: String) -> TVPlayerItem {
        TVPlayerItem(
            id: id,
            eyebrow: eyebrow,
            title: title,
            text: text,
            citation: citation,
            audioURL: url,
            artName: artName
        )
    }

    /// `lessons.py` and `text_chapters.py` pick the background by book.
    private static func artName(for sourcePDF: String) -> String {
        switch sourcePDF {
        case "Workbook": return "PlayerArtLesson"
        case "Text_A", "Text_B", "Text", "Manual": return "PlayerArtText"
        default: return "PlayerArt"
        }
    }
}

/// Live port of `video_builder.py` `FORMAT_CONFIGS["horizontal"]`.
struct TVPlayerView: View {
    let item: TVPlayerItem

    @Environment(AudioManager.self) private var audio
    @Environment(\.dismiss) private var dismiss

    @State private var showTransport = true
    @State private var hideTransportTask: Task<Void, Never>?
    @State private var startTask: Task<Void, Never>?
    @State private var clock = PlayheadClock()
    @State private var startedAt = Date()
    @State private var crawlNudge: CGFloat = 0

    private var display: String {
        TVPlayerText.normalized(item.text)
    }

    private var hasAudio: Bool {
        if let url = item.audioURL, !url.isEmpty { return true }
        return false
    }

    private var wordCount: Int {
        display.split(whereSeparator: \.isWhitespace).count
    }

    /// Audio duration is the video duration, the way `build_video` counts
    /// `total_frames = duration * FPS`. Title hold is the first two seconds
    /// of that, not extra time on the end.
    private var videoDuration: Double {
        if hasAudio, audio.duration > 1 { return audio.duration }
        return max(
            TVPlayerLayout.titleHold + 8,
            Double(wordCount) / TVPlayerLayout.wordsPerSecond
        )
    }

    private var timelinePaused: Bool {
        hasAudio && audio.hasActiveAudio && !audio.isPlaying
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
            let predicted = clock.time(at: .now, duration: videoDuration)
            if abs(time - predicted) > 0.85 {
                clock.sync(media: time, playing: audio.isPlaying)
            }
        }
        .onPlayPauseCommand {
            guard hasAudio, audio.hasActiveAudio else { return }
            audio.togglePlayback()
            revealTransport()
        }
        .onMoveCommand(perform: move)
        .onExitCommand { dismiss() }
    }

    private func playerCanvas(at date: Date) -> some View {
        let t = mediaTime(at: date)
        return GeometryReader { geo in
            ZStack {
                Image(item.artName)
                    .resizable()
                    .frame(width: geo.size.width, height: geo.size.height)

                TVPlayerScrollLayer(
                    text: display,
                    time: t,
                    duration: videoDuration,
                    size: geo.size,
                    nudge: crawlNudge
                )

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

    private var transport: some View {
        HStack(spacing: 24) {
            Button {
                guard audio.hasActiveAudio else { return }
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
        let t: Double
        if hasAudio, audio.hasActiveAudio {
            t = TVPlayerLayout.titleHold + clock.time(at: date, duration: .infinity)
        } else {
            t = date.timeIntervalSince(startedAt)
        }
        return min(max(0, t), videoDuration)
    }

    private func start() {
        startedAt = Date()
        UIApplication.shared.isIdleTimerDisabled = true
        revealTransport()
        guard let url = item.audioURL, !url.isEmpty else { return }
        // `video_builder.py` delays the MP3 with `-itsoffset TITLE_HOLD_SECONDS`
        // so the title card is silent and the voice starts with the crawl.
        startTask = Task {
            try? await Task.sleep(nanoseconds: TVPlayerLayout.titleHoldNanos)
            guard !Task.isCancelled else { return }
            audio.play(url: url, title: item.eyebrow)
            clock.sync(media: 0, playing: true)
        }
    }

    private func stop() {
        startTask?.cancel()
        hideTransportTask?.cancel()
        UIApplication.shared.isIdleTimerDisabled = false
        if hasAudio { audio.stop() }
    }

    private func move(_ direction: MoveCommandDirection) {
        switch direction {
        case .left:
            guard hasAudio, audio.hasActiveAudio else { return }
            audio.skip(by: -10)
            revealTransport()
        case .right:
            guard hasAudio, audio.hasActiveAudio else { return }
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

/// Horizontal YouTube numbers from `video_builder.py` `FORMAT_CONFIGS`.
private enum TVPlayerLayout {
    static let designHeight: CGFloat = 1080
    static let fontSize: CGFloat = 52
    static let marginX: CGFloat = 80
    static let boxPadX: CGFloat = 40
    static let boxPadY: CGFloat = 30
    static let boxRadius: CGFloat = 20
    static let lineSpacing: CGFloat = 16
    static let outline: CGFloat = 2
    static let boxAlpha: Double = 150.0 / 255.0
    static let titleHold: Double = 2.0
    static let titleHoldNanos: UInt64 = 2_000_000_000
    static let scrollSpeed: Double = 0.85
    static let wordsPerSecond: Double = 2.4
    static let holdOffscreen: CGFloat = 100
    static let nudgeStep: CGFloat = 80
    static let transportFadeNanos: UInt64 = 4_000_000_000
    static let fontName = "Helvetica"
}

/// Whitespace collapse and character wrap from `_wrap_text` in `video_builder.py`.
private enum TVPlayerText {
    static func normalized(_ raw: String) -> String {
        PunctuationSpacing.repaired(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func helvetica(_ size: CGFloat) -> UIFont {
        UIFont(name: TVPlayerLayout.fontName, size: size) ?? .systemFont(ofSize: size)
    }

    static func wrap(_ text: String, font: UIFont, textWidth: CGFloat) -> [String] {
        let sample = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        let avg = (sample as NSString)
            .size(withAttributes: [.font: font]).width / CGFloat(sample.count)
        let width = max(8, Int(textWidth / max(avg, 1)))
        return wrapWords(text, width: width)
    }

    /// Pillow `font.getbbox("Ay")` height: cap plus descender, not UIFont's
    /// line height. Plus `line_spacing = 16`.
    static func lineStride(font: UIFont, scale: CGFloat) -> CGFloat {
        (font.capHeight - font.descender) + TVPlayerLayout.lineSpacing * scale
    }

    static func wrapWords(_ text: String, width: Int) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            if word.count > width {
                if !current.isEmpty {
                    lines.append(current)
                    current = ""
                }
                var rest = word
                while rest.count > width {
                    let idx = rest.index(rest.startIndex, offsetBy: width)
                    lines.append(String(rest[..<idx]))
                    rest = String(rest[idx...])
                }
                current = rest
                continue
            }
            let candidate = current.isEmpty ? word : current + " " + word
            if candidate.count <= width {
                current = candidate
            } else {
                lines.append(current)
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}

/// One frame of the crawl: rounded box riding with the text, the way
/// `build_video` composites each Pillow frame.
private struct TVPlayerScrollLayer: View {
    let text: String
    let time: Double
    let duration: Double
    let size: CGSize
    let nudge: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            draw(context: &context, size: canvasSize)
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let scale = size.height / TVPlayerLayout.designHeight
        let fontSize = TVPlayerLayout.fontSize * scale
        let font = TVPlayerText.helvetica(fontSize)
        let marginX = TVPlayerLayout.marginX * scale
        let textWidth = size.width - 2 * marginX
        let lines = TVPlayerText.wrap(text, font: font, textWidth: textWidth)
        let stride = TVPlayerText.lineStride(font: font, scale: scale)
        let blockHeight = CGFloat(lines.count) * stride
        let yOffset = Self.yOffset(
            time: time,
            duration: duration,
            height: size.height,
            blockHeight: blockHeight,
            scale: scale
        ) + nudge

        drawBox(
            context: &context,
            size: size,
            yOffset: yOffset,
            blockHeight: blockHeight,
            scale: scale
        )
        drawLines(
            context: &context,
            size: size,
            lines: lines,
            font: font,
            fontSize: fontSize,
            yOffset: yOffset,
            stride: stride,
            scale: scale
        )
    }

    /// `y_offset = height - scroll_frame * pixels_per_frame` after the hold.
    static func yOffset(
        time: Double,
        duration: Double,
        height: CGFloat,
        blockHeight: CGFloat,
        scale: CGFloat
    ) -> CGFloat {
        if time < TVPlayerLayout.titleHold {
            return height + TVPlayerLayout.holdOffscreen * scale
        }
        let scrolling = max(0.1, duration - TVPlayerLayout.titleHold)
        let totalScroll = height + blockHeight
        let pixelsPerSecond = totalScroll / scrolling * TVPlayerLayout.scrollSpeed
        return height - CGFloat(time - TVPlayerLayout.titleHold) * pixelsPerSecond
    }

    private func drawBox(
        context: inout GraphicsContext,
        size: CGSize,
        yOffset: CGFloat,
        blockHeight: CGFloat,
        scale: CGFloat
    ) {
        let padX = TVPlayerLayout.boxPadX * scale
        let padY = TVPlayerLayout.boxPadY * scale
        let marginX = TVPlayerLayout.marginX * scale
        let boxTop = yOffset - padY
        let boxBottom = yOffset + blockHeight + padY
        guard boxBottom > 0, boxTop < size.height else { return }
        let rect = CGRect(
            x: marginX - padX,
            y: max(boxTop, -20 * scale),
            width: size.width - 2 * (marginX - padX),
            height: min(boxBottom, size.height + 20 * scale) - max(boxTop, -20 * scale)
        )
        let path = Path(
            roundedRect: rect,
            cornerRadius: TVPlayerLayout.boxRadius * scale
        )
        context.fill(path, with: .color(.black.opacity(TVPlayerLayout.boxAlpha)))
    }

    private func drawLines(
        context: inout GraphicsContext,
        size: CGSize,
        lines: [String],
        font: UIFont,
        fontSize: CGFloat,
        yOffset: CGFloat,
        stride: CGFloat,
        scale: CGFloat
    ) {
        let outline = TVPlayerLayout.outline * scale
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        for (i, line) in lines.enumerated() {
            let y = yOffset + CGFloat(i) * stride
            guard y > -stride, y < size.height + stride else { continue }
            let lineW = (line as NSString).size(withAttributes: attrs).width
            let x = (size.width - lineW) / 2
            let origin = CGPoint(x: x, y: y)
            let black = context.resolve(
                Text(line)
                    .font(.custom(TVPlayerLayout.fontName, size: fontSize))
                    .foregroundColor(.black)
            )
            let white = context.resolve(
                Text(line)
                    .font(.custom(TVPlayerLayout.fontName, size: fontSize))
                    .foregroundColor(.white)
            )
            for dx in [-outline, 0, outline] {
                for dy in [-outline, 0, outline] {
                    if dx == 0 && dy == 0 { continue }
                    context.draw(
                        black,
                        at: CGPoint(x: origin.x + dx, y: origin.y + dy),
                        anchor: .topLeading
                    )
                }
            }
            context.draw(white, at: origin, anchor: .topLeading)
        }
    }
}

/// Interpolates between the audio observer's 0.5s ticks so the crawl does
/// not stutter. Resyncs on play/pause and on a seek larger than a tick.
/// Installed by the Read tab so a lesson, section, or introduction Select
/// starts the player instead of pushing a reading.
struct OpenPlayerAction: Sendable {
    private let handler: @Sendable (TVPlayerItem) -> Void

    init(handler: @escaping @Sendable (TVPlayerItem) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ item: TVPlayerItem) { handler(item) }
}

private struct OpenPlayerKey: EnvironmentKey {
    static let defaultValue = OpenPlayerAction { _ in
        assertionFailure("openPlayer used with no player installed")
    }
}

extension EnvironmentValues {
    var openPlayer: OpenPlayerAction {
        get { self[OpenPlayerKey.self] }
        set { self[OpenPlayerKey.self] = newValue }
    }
}

private struct PlayheadClock {
    var originMedia: Double = 0
    var originWall: Date = .now
    var playing = false

    func time(at date: Date, duration: Double) -> Double {
        let raw = playing
            ? originMedia + date.timeIntervalSince(originWall)
            : originMedia
        if duration > 0, duration.isFinite {
            return min(max(0, raw), duration)
        }
        return max(0, raw)
    }

    mutating func sync(media: Double, playing: Bool, at date: Date = .now) {
        originMedia = media
        originWall = date
        self.playing = playing
    }
}
#endif
