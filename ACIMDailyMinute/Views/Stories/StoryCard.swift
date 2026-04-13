import SwiftUI
import SwiftData

struct StoryCard: View {
    let story: Story
    let sources: [Source]
    let correction: Correction?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let correction {
                correctionView(correction)
            } else {
                factView
            }

            sourceBadges

            if let ownershipText = ownershipLine {
                Text(ownershipText)
                    .font(.acimCaption2)
                    .foregroundStyle(.secondary)
            }

            Text(relativeTime)
                .font(.acimCaption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(correction != nil ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let correction {
            parts.append("Correction.")
            parts.append("Original: \(correction.originalFact)")
            parts.append("Corrected to: \(correction.correctedFact)")
        } else {
            parts.append(story.fact)
        }
        let badges = parseSourceDisplay(story.sourceDisplay)
        let sourceText = badges.map { "\($0.name), accuracy \($0.accuracy)" }.joined(separator: ". ")
        if !sourceText.isEmpty { parts.append("Sources: \(sourceText)") }
        if let ownership = ownershipLine { parts.append(ownership) }
        parts.append(relativeTime)
        return parts.joined(separator: ". ")
    }

    // MARK: - Fact

    private var factView: some View {
        Text(story.fact)
            .font(.acimBody)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Correction

    private func correctionView(_ correction: Correction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Correction", systemImage: "exclamationmark.triangle")
                .font(.acimCaption)
                .fontWeight(.semibold)
                .foregroundStyle(.red)

            Text(correction.originalFact)
                .font(.acimBody)
                .strikethrough()
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.down")
                .foregroundStyle(.red.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)

            Text(correction.correctedFact)
                .font(.acimBody)
                .foregroundStyle(.primary)

            if !correction.reason.isEmpty {
                Text(correction.reason)
                    .font(.acimCaption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - Source Badges

    private var sourceBadges: some View {
        let parsed = parseSourceDisplay(story.sourceDisplay)
        return FlowLayout(spacing: 6) {
            ForEach(parsed, id: \.name) { badge in
                HStack(spacing: 4) {
                    Text(badge.name)
                        .font(.acimCaption)
                        .fontWeight(.medium)
                    Text(String(format: "%.1f", badge.accuracy))
                        .font(.acimCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(ratingColor(badge.accuracy))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(white: 0.17).opacity(0.6))
                .clipShape(Capsule())
                .accessibilityLabel("\(badge.name), accuracy \(String(format: "%.1f", badge.accuracy))")
            }
        }
    }

    // MARK: - Ownership

    private var ownershipLine: String? {
        let parsed = parseSourceDisplay(story.sourceDisplay)
        let owners = parsed.compactMap { badge -> String? in
            guard let source = sources.first(where: { $0.name == badge.name }) else { return nil }
            let typeLabel = source.controlType
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return "\(source.ownerDisplay.isEmpty ? source.owner : source.ownerDisplay) (\(typeLabel))"
        }
        let unique = Array(Set(owners))
        return unique.isEmpty ? nil : unique.joined(separator: " · ")
    }

    // MARK: - Relative Time

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: story.publishedAt, relativeTo: Date())
    }

    // MARK: - Helpers

    private func ratingColor(_ rating: Double) -> Color {
        if rating >= 8.5 { return Color(.systemGreen).opacity(0.9) }
        if rating >= 7.0 { return Color(.systemBlue).opacity(0.9) }
        return Color(.systemOrange).opacity(0.9)
    }
}

// MARK: - Source Display Parser

struct SourceBadge: Hashable {
    let name: String
    let accuracy: Double
    let bias: Double
}

func parseSourceDisplay(_ display: String) -> [SourceBadge] {
    guard !display.isEmpty else { return [] }
    let parts = display.components(separatedBy: " · ")
    return parts.compactMap { part in
        let trimmed = part.trimmingCharacters(in: .whitespaces)
        guard let lastSpace = trimmed.lastIndex(of: " ") else { return nil }
        let name = String(trimmed[trimmed.startIndex..<lastSpace])
        let ratingsStr = String(trimmed[trimmed.index(after: lastSpace)...])
        let ratings = ratingsStr.components(separatedBy: "|")
        let accuracy = Double(ratings.first ?? "") ?? 0.0
        let bias = ratings.count > 1 ? Double(ratings[1]) ?? 0.0 : 0.0
        return SourceBadge(name: name, accuracy: accuracy, bias: bias)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
