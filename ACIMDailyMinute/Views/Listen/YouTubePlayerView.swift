// ⛔ The YouTube embed is a WKWebView, and tvOS has NO WebKit at all — the one
// capability gap on the TV that no fence can paper over. The guard is on the
// FRAMEWORK and wraps the whole file, imports included: fencing only the two
// platform structs left the shared `extension YouTubePlayerView` at the tail
// referring to a type that no longer existed, and the error named the extension
// rather than the cause.
//
// Video on the TV needs either a direct MP4 URL the pipeline does not yet
// publish, or a hand-off to the YouTube tvOS app. Audio is the tvOS path: the
// archive.org MP3s stream there exactly as they do to a phone.
#if canImport(WebKit)
import SwiftUI
import WebKit
#if os(iOS)
struct YouTubePlayerView: UIViewRepresentable {
    let videoURL: String
    var autoplay: Bool = false

    /// YouTube's own control bar and title/share overlay. Wanted on the small
    /// inline card in Listen; unwanted full screen, where they sit on top of
    /// the reading burned into the frame for the first several seconds.
    var showsControls: Bool = true

    /// Whether a tap that escapes the embed may leave the app. True for the
    /// inline card, where "Watch on YouTube" is a reasonable thing to offer.
    /// False full screen, where an accidental tap would eject the reader
    /// mid-lesson.
    var opensExternalLinks: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(opensExternalLinks: opensExternalLinks)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        loadVideoIfNeeded(webView, coordinator: context.coordinator)
    }
}
#elseif os(macOS)
struct YouTubePlayerView: NSViewRepresentable {
    let videoURL: String
    var autoplay: Bool = false
    var showsControls: Bool = true
    var opensExternalLinks: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(opensExternalLinks: opensExternalLinks)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadVideoIfNeeded(webView, coordinator: context.coordinator)
    }
}
#endif

// MARK: - Shared Logic

extension YouTubePlayerView {
    func loadVideoIfNeeded(_ webView: WKWebView, coordinator: Coordinator) {
        guard coordinator.loadedVideoID != videoURL else { return }

        // `cc_load_policy=0` only expresses a preference — a viewer whose YouTube
        // account forces captions on still gets them, and these videos burn the
        // reading into the frame, so captions sit on top of the text. The
        // iframe API's `unloadModule` is what actually removes them, and
        // `enablejsapi=1` is what lets us call it.
        //
        // `controls=0` is the only parameter that actually suppresses the
        // player chrome. `modestbranding` used to soften it and was deliberately
        // set here, but YouTube retired it in 2023 — it is omitted rather than
        // left in place looking load-bearing.
        let params = "playsinline=1&fs=1&rel=0"
            + "&cc_load_policy=0&cc_lang_pref=en&iv_load_policy=3&enablejsapi=1"
            + (showsControls ? "" : "&controls=0&disablekb=1")
            + (autoplay ? "&autoplay=1" : "")
            + "&origin=https://www.acimdailyminute.org"

        let embedSrc: String
        if videoURL.contains("youtube.com/embed/") {
            let separator = videoURL.contains("?") ? "&" : "?"
            embedSrc = "\(videoURL)\(separator)\(params)"
        } else if let videoID = YouTubeID.extract(from: videoURL) {
            embedSrc = "https://www.youtube.com/embed/\(videoID)?\(params)"
        } else {
            return
        }

        coordinator.loadedVideoID = videoURL

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        * { margin: 0; padding: 0; }
        body { background: #000; overflow: hidden; }
        iframe { width: 100%; height: 100%; position: absolute; top: 0; left: 0; }
        </style>
        </head>
        <body>
        <iframe
            id="player"
            src="\(embedSrc)"
            frameborder="0"
            allowfullscreen
            allow="autoplay; encrypted-media; fullscreen; picture-in-picture">
        </iframe>
        <script src="https://www.youtube.com/iframe_api"></script>
        <script>
        // Attach to the iframe already in the page rather than letting the API
        // build its own, so the playlist/index semantics of the embed URL are
        // preserved exactly.
        function hideCaptions(player) {
            try { player.unloadModule('captions'); } catch (e) {}
            try { player.unloadModule('cc'); } catch (e) {}
        }
        function onYouTubeIframeAPIReady() {
            new YT.Player('player', {
                events: {
                    onReady: function (event) { hideCaptions(event.target); },
                    // The player re-loads the captions module when playback
                    // starts, so once on ready is not enough.
                    onStateChange: function (event) { hideCaptions(event.target); }
                }
            });
        }
        </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: URL(string: "https://www.acimdailyminute.org"))
    }

}

// MARK: - Coordinator

extension YouTubePlayerView {
    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedVideoID: String?
        private let opensExternalLinks: Bool

        init(opensExternalLinks: Bool) {
            self.opensExternalLinks = opensExternalLinks
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            let urlString = url.absoluteString

            // Allow the initial HTML load and YouTube embed iframe
            if navigationAction.navigationType == .other {
                return .allow
            }

            // Allow YouTube embed URLs within the iframe
            if urlString.contains("youtube.com/embed") {
                return .allow
            }

            // Full screen, the reader is mid-lesson and every pixel belongs to
            // the video: a stray tap on a surviving YouTube affordance must go
            // nowhere rather than hand the session to Safari.
            guard opensExternalLinks else { return .cancel }

            // Open all other URLs (Watch on YouTube, etc.) in default browser
            _ = await MainActor.run {
                #if os(iOS) || os(tvOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
            }
            return .cancel
        }
    }
}
#endif
