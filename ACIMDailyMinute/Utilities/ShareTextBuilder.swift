import Foundation

enum ShareTextBuilder {
    static func shareText(
        fact: String,
        sourceDisplay: String,
        sources: [Source]
    ) -> String {
        let badges = parseSourceDisplay(sourceDisplay)

        let sourceLines = badges.map { badge -> String in
            let accuracy = String(format: "%.1f", badge.accuracy)
            let matched = sources.first { $0.name == badge.name }
            let ownerPart: String
            if let source = matched {
                let display = source.ownerDisplay.isEmpty ? source.owner : source.ownerDisplay
                ownerPart = display.isEmpty ? "" : " · \(display)"
            } else {
                ownerPart = ""
            }
            return "  \(badge.name) (\(accuracy))\(ownerPart)"
        }

        var parts: [String] = [fact]

        if !sourceLines.isEmpty {
            parts.append("Sources:\n" + sourceLines.joined(separator: "\n"))
        }

        parts.append("www.acimdailyminute.org")

        return parts.joined(separator: "\n\n")
    }
}
