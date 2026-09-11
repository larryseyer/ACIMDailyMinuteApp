import SwiftUI

/// Display-only rendering of a stored citation. Does not parse, does not
/// look up a destination, and does not become a button.
///
/// The rule is total and is one line: replace every `-` and every `.` with
/// `·`. Separators sit at 45% opacity; alphanumeric runs stay full strength.
enum CitationRender {
    static let separator: Character = "·"

    static func displayString(_ raw: String) -> String {
        String(raw.map { $0 == "-" || $0 == "." ? separator : $0 })
    }
}

struct CitationLabel: View {
    let raw: String?
    var font: Font = .acimAddress

    var body: some View {
        if let raw, !raw.isEmpty {
            Text(attributed(raw))
                .font(font)
                .foregroundStyle(Color.acimGold)
                .monospacedDigit()
                .tracking(0.28)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func attributed(_ raw: String) -> AttributedString {
        var result = AttributedString()
        for character in CitationRender.displayString(raw) {
            var piece = AttributedString(String(character))
            if character == CitationRender.separator {
                piece.foregroundColor = Color.acimGold.opacity(0.45)
            }
            result.append(piece)
        }
        return result
    }
}
