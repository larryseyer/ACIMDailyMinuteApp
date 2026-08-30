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
/// keeps the Listen tab cheap to open.
struct LiteYouTubeCard: View {
    /// The video whose thumbnail stands in for the playlist — normally whichever
    /// one the playlist is going to start on.
    let videoID: String?

    /// The URL handed to the real player on tap. A playlist embed, so playlist
    /// semantics survive the swap.
    let playerURL: String

    /// Spoken by VoiceOver in place of the image, e.g. "Daily Minute playlist".
    let accessibilityTitle: String

    @State private var isActivated = false
    @State private var useFallbackThumbnail = false

    var body: some View {
        Group {
            if isActivated {
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
                    // `maxresdefault` only exists for uploads that supplied a
                    // high-resolution thumbnail; `hqdefault` is always present.
                    // Retry once at the lower size before giving up on artwork.
                    Color.clear
                        .onAppear { useFallbackThumbnail = true }
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
