// ⛔ A YouTube embed is a WKWebView and tvOS has no WebKit, so this whole
// card is iPhone, iPad, and Mac. On the TV the picture is rebuilt from
// the archive.org MP3s.
#if os(iOS) || os(macOS)
import SwiftUI

/// A YouTube embed that shows *our* thumbnail until it is played.
///
/// A live `<iframe>` paints YouTube's own poster over the artwork — the channel
/// avatar, the video title and a share button, all on top of the frame the
/// publisher designed. None of that is suppressible from the embed URL any more
/// (`modestbranding` was retired in 2023).
///
/// So the idle state is not an embed at all: it is the thumbnail image fetched
/// straight from `img.youtube.com`, with a play button drawn over it. The real
/// player is only created once the reader taps, at which point the chrome is
/// wanted anyway because they are watching. Loading no web view until then also
/// keeps the Video tab cheap to open. A 404 thumbnail is not the end of the
/// day: `videoIDs` is the list `YouTubeID.candidates` built, and this card
/// walks it until one image loads.
struct LiteYouTubeCard: View {
    /// Ids to try, live one first. A dead re-upload 404s every thumbnail
    /// size; the next id is today's video.
    let videoIDs: [String]

    /// Spoken by VoiceOver in place of the image, e.g. "Daily Minute".
    let accessibilityTitle: String

    @State private var isActivated = false
    @State private var index = 0
    @State private var useFallbackThumbnail = false
    @State private var artworkFailed = false

    private var videoID: String? {
        guard videoIDs.indices.contains(index) else { return nil }
        return videoIDs[index]
    }

    private var playerURL: String {
        guard let videoID else { return "" }
        return "https://www.youtube.com/embed/\(videoID)"
    }

    var body: some View {
        Group {
            if videoID == nil || artworkFailed {
                unavailable
            } else if isActivated {
                YouTubePlayerView(videoURL: playerURL, autoplay: true)
            } else {
                facade
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Idle state

    private var facade: some View {
        Button {
            isActivated = true
        } label: {
            ZStack {
                Color.black
                thumbnail
                playBadge
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(accessibilityTitle)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    // `maxresdefault` is missing on some real uploads;
                    // `hqdefault` 404s only when the id itself is dead.
                    Color.clear
                        .onAppear {
                            let step = YouTubeID.thumbnailAdvance(
                                useFallback: useFallbackThumbnail,
                                index: index,
                                count: videoIDs.count
                            )
                            index = step.index
                            useFallbackThumbnail = step.useFallback
                            artworkFailed = step.giveUp
                        }
                case .empty:
                    ProgressView().tint(.white)
                @unknown default:
                    Color.clear
                }
            }
        }
    }

    private var thumbnailURL: URL? {
        guard let videoID else { return nil }
        let name = useFallbackThumbnail ? "hqdefault" : "maxresdefault"
        return URL(string: "https://img.youtube.com/vi/\(videoID)/\(name).jpg")
    }

    private var unavailable: some View {
        Text("Video is unavailable.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            .background(Color.black.opacity(0.85))
            .accessibilityLabel("Video is unavailable")
    }

    /// YouTube's own play button, redrawn: the reader is expecting it, and it is
    /// the one piece of YouTube chrome that belongs on the artwork.
    private var playBadge: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(red: 1.0, green: 0.0, blue: 0.0))
            .frame(width: 68, height: 48)
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
    }
}
#endif
