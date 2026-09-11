import SwiftUI
import SwiftData

#if os(iOS) || os(macOS)

/// The full player. Artwork is the passage. Transport, scrub, download,
/// mark listened, share and save live here; the compact bar opens it.
struct NowPlayingView: View {
    @Environment(AudioManager.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [Bookmark]
    @AppStorage(PlaybackHistory.defaultsKey) private var listenedData: Data = Data()
    @State private var downloadRevision = 0
    @State private var isDownloading = false
    @State private var scrubbing: Double?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 0) {
                    artwork
                        .padding(.top, 6)
                        .padding(.bottom, 24)
                    titles
                    scrubber
                        .padding(.top, 22)
                    transport
                        .padding(.top, 26)
                    pills
                        .padding(.top, 30)
                }
                .padding(.horizontal, Metric.gutter)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.acimInk.ignoresSafeArea())
        .readableContentWidth()
    }

    private var header: some View {
        ZStack {
            Text(audio.currentTitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 56)
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
    }

    private var artwork: some View {
        let passage = audio.context.artworkText.isEmpty
            ? audio.currentTitle
            : audio.context.artworkText
        return ZStack {
            RoundedRectangle(cornerRadius: Metric.art, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.acimRaised, Color.acimSurface],
                        startPoint: UnitPoint(x: 0.4, y: 0),
                        endPoint: UnitPoint(x: 0.6, y: 1)
                    )
                )
            RadialGradient(
                colors: [Color.acimGold.opacity(0.34), Color.clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: 210
            )
            .clipShape(RoundedRectangle(cornerRadius: Metric.art, style: .continuous))
            Text(passage)
                .font(.system(size: 23, design: .serif).italic())
                .multilineTextAlignment(.center)
                .lineSpacing(23 * 0.4)
                .foregroundStyle(.primary)
                .frame(maxWidth: 26 * 11.5)
                .lineLimit(6)
                .padding(26)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 232)
        .clipShape(RoundedRectangle(cornerRadius: Metric.art, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.art, style: .continuous)
                .stroke(Color.acimRule, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(passage)
    }

    private var titles: some View {
        VStack(spacing: 4) {
            Text(audio.currentTitle)
                .font(.acimSubject)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            if !audio.context.subtitle.isEmpty {
                Text(audio.context.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var shownTime: Double {
        scrubbing ?? audio.currentTime
    }

    private var scrubber: some View {
        VStack(spacing: 9) {
            GeometryReader { geo in
                let fraction = AudioTransport.sliderFraction(
                    position: shownTime,
                    duration: audio.duration
                )
                let x = geo.size.width * fraction
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.acimRaised)
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.acimGold)
                        .frame(width: max(0, x), height: 3)
                    Circle()
                        .fill(Color.acimGold)
                        .frame(width: 11, height: 11)
                        .offset(x: x - 5.5)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let f = max(0, min(1, value.location.x / geo.size.width))
                            scrubbing = f * max(audio.duration, 0)
                        }
                        .onEnded { value in
                            let f = max(0, min(1, value.location.x / geo.size.width))
                            audio.seek(to: f * max(audio.duration, 0))
                            scrubbing = nil
                        }
                )
            }
            .frame(height: 44)
            HStack {
                Text(AudioTransport.timeLabel(shownTime))
                Spacer()
                Text(AudioTransport.remainingLabel(position: shownTime, duration: audio.duration))
            }
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue(AudioTransport.timeLabel(shownTime))
    }

    private var transport: some View {
        HStack(spacing: 34) {
            skipButton(label: "−15", accessibility: "Skip back 15 seconds") {
                audio.skip(by: -15)
            }
            seekButton(systemImage: "backward.fill", accessibility: "Jump to start") {
                audio.seek(to: 0)
            }
            Button {
                audio.togglePlayback()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.acimOnGold)
                    .frame(width: 68, height: 68)
                    .background(Color.acimGold, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audio.isPlaying ? "Pause" : "Play")
            seekButton(systemImage: "forward.fill", accessibility: "Jump to end") {
                audio.seek(to: audio.duration)
            }
            skipButton(label: "+15", accessibility: "Skip forward 15 seconds") {
                audio.skip(by: 15)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func skipButton(label: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    private func seekButton(systemImage: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 27))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }

    private var pills: some View {
        HStack(spacing: 12) {
            if !audio.currentEpisodeID.isEmpty {
                downloadPill
                listenedPill
            }
            sharePill
            if !audio.context.bookmarkKey.isEmpty {
                savePill
            }
        }
        .frame(maxWidth: .infinity)
        .id(downloadRevision)
    }

    private var isDownloaded: Bool {
        _ = downloadRevision
        return AudioDownloadStore.isDownloaded(audio.currentEpisodeID)
    }

    private var isListened: Bool {
        _ = listenedData
        return PlaybackHistory.playedAt(audio.currentEpisodeID) != nil
    }

    private var isSaved: Bool {
        bookmarks.contains { $0.itemKey == audio.context.bookmarkKey }
    }

    private var downloadPill: some View {
        Button {
            toggleDownload()
        } label: {
            Image(systemName: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
            .font(.acimChrome)
            .foregroundStyle(isDownloaded ? Color.acimGold : Color.primary)
            .frame(width: 38, height: 38)
            .background(Color.acimRaised, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(isDownloading)
        .accessibilityLabel(isDownloaded ? "Remove download" : "Download")
    }

    private var listenedPill: some View {
        Button {
            toggleListened()
        } label: {
            Image(systemName: isListened ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.acimChrome)
                .foregroundStyle(isListened ? Color.acimGold : Color.primary)
                .frame(width: 38, height: 38)
                .background(Color.acimRaised, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isListened ? "Mark unplayed" : "Mark listened")
    }

    private var shareText: String {
        let text = audio.context.shareText
        return text.isEmpty ? audio.currentTitle : text
    }

    private var sharePill: some View {
        ShareLink(item: shareText) {
            Image(systemName: "square.and.arrow.up")
                .font(.acimChrome)
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(Color.acimRaised, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel("Share")
    }

    private var savePill: some View {
        Button {
            BookmarkStore.toggle(
                key: audio.context.bookmarkKey,
                channel: audio.context.bookmarkChannel,
                in: modelContext
            )
        } label: {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.acimChrome)
                .foregroundStyle(isSaved ? Color.acimGold : Color.primary)
                .frame(width: 38, height: 38)
                .background(Color.acimRaised, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(isSaved ? "Remove from Saved" : "Save")
    }

    private func toggleDownload() {
        let id = audio.currentEpisodeID
        guard !id.isEmpty else { return }
        if AudioDownloadStore.isDownloaded(id) {
            AudioDownloadStore.delete(id)
            downloadRevision += 1
            return
        }
        isDownloading = true
        let remote = audio.currentURL
        Task {
            try? await AudioDownloadStore.download(episodeID: id, remoteURL: remote)
            isDownloading = false
            downloadRevision += 1
        }
    }

    private func toggleListened() {
        let id = audio.currentEpisodeID
        guard !id.isEmpty else { return }
        if PlaybackHistory.playedAt(id) != nil {
            PlaybackHistory.clear(id)
            PlaybackProgressStore.clear(id)
            if !audio.currentURL.isEmpty {
                PlaybackProgressStore.clear(audio.currentURL)
            }
        } else {
            PlaybackHistory.markPlayed(id)
        }
    }
}

#endif
