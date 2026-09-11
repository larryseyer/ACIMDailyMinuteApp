import SwiftUI

/// One Video-tab catalogue row. Every row is tappable; absence of a
/// recording is not an empty state and not an apology.
struct VideoPlayableRow: View {
    let title: String
    var subtitle: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.acimCaption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    Text(title)
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
