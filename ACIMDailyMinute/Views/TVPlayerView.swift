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

/// Full-bleed art, the passage over it, narration underneath — the YouTube
/// upload, drawn live so it covers every bundled reading and stays 4K.
struct TVPlayerView: View {
    let item: TVPlayerItem

    @Environment(AudioManager.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @StateObject private var page = VerticalPageState()
    @State private var showTransport = true
    @State private var hideTransportTask: Task<Void, Never>?

    private var display: String { ReadingText.displayString(from: item.text) }
    private var hasAudio: Bool {
        if let url = item.audioURL, !url.isEmpty { return true }
        return false
    }

    var body: some View {
        ZStack {
            Image("PlayerArt")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.72))
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text(item.eyebrow)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.acimGold)
                    .tracking(1.2)

                if let title = item.title {
                    Text(title)
                        .font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TVPageableScroll(page: page, capturesKeys: true) {
                    Text(display)
                        .font(.system(size: 32, design: .serif))
                        .foregroundStyle(Color(white: 0.96))
                        .lineSpacing(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let citation = item.citation {
                    Text(citation)
                        .font(.system(.title3, design: .serif).italic())
                        .foregroundStyle(Color.acimGold)
                }

                Spacer(minLength: 0)

                if hasAudio, showTransport {
                    transport
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 96)
            .padding(.top, 56)
            .padding(.bottom, 40)
        }
        .onAppear {
            if let url = item.audioURL, !url.isEmpty {
                audio.play(url: url, title: item.eyebrow)
                UIApplication.shared.isIdleTimerDisabled = true
            }
            revealTransport()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            hideTransportTask?.cancel()
        }
        .onPlayPauseCommand {
            guard hasAudio else { return }
            audio.togglePlayback()
            revealTransport()
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                guard hasAudio else { return }
                audio.skip(by: -10)
                revealTransport()
            case .right:
                guard hasAudio else { return }
                audio.skip(by: 10)
                revealTransport()
            default:
                break
            }
        }
        .onExitCommand { dismiss() }
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
                ProgressView(value: audio.currentTime / audio.duration)
                    .tint(Color.acimGold)
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

    private func revealTransport() {
        showTransport = true
        hideTransportTask?.cancel()
        hideTransportTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { showTransport = false }
        }
    }
}
#endif
