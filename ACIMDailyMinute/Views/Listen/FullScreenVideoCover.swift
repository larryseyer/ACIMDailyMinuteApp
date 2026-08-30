import SwiftUI

#if os(iOS)

/// Full-bleed autoplaying video, presented over whatever asked for it.
///
/// Locks to landscape on iPhone for as long as it is on screen and hands
/// orientation back on dismiss. iPad keeps its own orientation — see
/// `OrientationController.forcesRotation`.
///
/// Shared by the Lessons spine (choosing a lesson opens its video) and the
/// Listen tab (an episode with no published audio still has a video).
struct FullScreenVideoCover: View {
    let videoURL: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black
                .ignoresSafeArea()

            // YouTube's own chrome is suppressed here: it drew over the reading
            // burned into the frame, and it sat exactly where this button does.
            YouTubePlayerView(
                videoURL: videoURL,
                autoplay: true,
                showsControls: false,
                opensExternalLinks: false
            )
            .ignoresSafeArea()

            closeButton
                .zIndex(1)
        }
        .statusBarHidden()
        .onAppear { OrientationController.lockLandscape() }
        .onDisappear { OrientationController.unlock() }
    }

    /// The only control on this screen, so it has to survive a hurried tap over
    /// any frame of video: a full 44pt target, an explicit hit shape so near
    /// misses do not fall through to the web view, and a scrim disc so a white
    /// glyph still reads against a white frame. `safeAreaPadding` keeps it clear
    /// of the sensor housing, which lands on the leading edge in landscapeRight.
    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.55), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(12)
        .safeAreaPadding()
        .accessibilityLabel("Close video")
    }
}

#endif
