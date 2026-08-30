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

            YouTubePlayerView(videoURL: videoURL, autoplay: true)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                    .padding(20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close video")
        }
        .statusBarHidden()
        .onAppear { OrientationController.lockLandscape() }
        .onDisappear { OrientationController.unlock() }
    }
}

#endif
