import SwiftUI

/// Listen, Watch, Save, Share under Today's passage.
///
/// Listen is omitted when there is no audio. Watch is a visible pill, not a
/// long-press. Save and Share stay even when Listen is absent, so they do not
/// move.
struct TodayActionRow: View {
    let title: String
    var segmentId: Int = 0
    var lessonNumber: Int = 0
    var surfaceAudioURL: String? = nil
    var surfaceYouTubeID: String? = nil
    let shareText: String
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        #if os(tvOS)
        EmptyView()
        #else
        HStack(spacing: 9) {
            ReadingPlayControl(
                title: title,
                segmentId: segmentId,
                lessonNumber: lessonNumber,
                surfaceAudioURL: surfaceAudioURL,
                surfaceYouTubeID: surfaceYouTubeID,
                placement: .today
            )
            savePill
            sharePill
        }
        .padding(.top, 16)
        #endif
    }

    #if !os(tvOS)
    private var savePill: some View {
        Button(action: onSave) {
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
    #endif
}
