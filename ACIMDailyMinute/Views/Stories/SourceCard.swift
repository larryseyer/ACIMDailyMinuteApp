import SwiftUI

struct SourceCard: View {
    let badge: SourceBadge
    let source: Source?
    let startExpanded: Bool

    @State private var isExpanded: Bool

    init(badge: SourceBadge, source: Source?, startExpanded: Bool = false) {
        self.badge = badge
        self.source = source
        self.startExpanded = startExpanded
        self._isExpanded = State(initialValue: startExpanded)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            expandedContent
        } label: {
            collapsedContent
        }
        .tint(.secondary)
        .padding(12)
        .background(Color(white: 0.13).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Collapsed

    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(badge.name)
                    .font(.acimSubheadline)
                    .fontWeight(.semibold)

                Text(String(format: "%.1f", badge.accuracy))
                    .font(.acimCaption)
                    .fontWeight(.bold)
                    .foregroundStyle(ratingColor(badge.accuracy))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ratingColor(badge.accuracy).opacity(0.15))
                    .clipShape(Capsule())
            }

            if let source, !ownershipText(source).isEmpty {
                Text(ownershipText(source))
                    .font(.acimCaption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Expanded

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let source {
                VStack(spacing: 8) {
                    ratingRow("Accuracy", value: source.accuracy)
                    ratingRow("Bias", value: source.bias)
                    ratingRow("Speed", value: source.speed)
                    ratingRow("Consensus", value: source.consensus)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ownership")
                        .font(.acimCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(ownershipText(source))
                        .font(.acimCaption)
                    Text(source.controlType
                        .replacingOccurrences(of: "_", with: " ")
                        .capitalized)
                        .font(.acimCaption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Source details loading…")
                    .font(.acimCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func ratingRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.acimCaption)
                .frame(width: 72, alignment: .leading)
            ProgressView(value: value, total: 10)
                .frame(width: 80)
                .tint(ratingColor(value))
            Text(String(format: "%.1f", value))
                .font(.acimCaption)
                .fontWeight(.bold)
                .foregroundStyle(ratingColor(value))
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func ratingColor(_ value: Double) -> Color {
        if value >= 8.5 { return Color(.systemGreen).opacity(0.9) }
        if value >= 7.0 { return Color(.systemBlue).opacity(0.9) }
        return Color(.systemOrange).opacity(0.9)
    }

    private func ownershipText(_ source: Source) -> String {
        let display = source.ownerDisplay.isEmpty ? source.owner : source.ownerDisplay
        return display
    }
}
