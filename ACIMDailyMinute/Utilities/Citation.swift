import Foundation

/// Where a passage sits in the book, as a string a reader can carry to a
/// printed copy or into whatever replaces this app.
///
/// ⛔ This addresses THE EDITION THIS APP SHIPS, which is not the edition the
/// familiar `T-1.I.1:1` notation belongs to. Measured against the bundle: our
/// Chapter 1 is "INTRODUCTION TO MIRACLES" and carries 53 numbered miracle
/// principles rather than 50, and a chapter's Introduction occupies section 1.
/// Arabic section numbers are the visible signal that these are not those
/// citations. Emitting that notation would print a confident, precise, wrong
/// pointer into an export meant to outlive the app.
///
/// There is no sentence number, and that is measured rather than lazy: two
/// defensible sentence splitters disagree on 644 of 3,564 paragraphs, and no
/// published sentence numbering exists for this edition to settle which is
/// right. A `:1` would be a number this app invented and then made permanent.
///
/// Pure by design — no SwiftUI, no `CorpusService`, no `ReadingKey` — so a
/// `swiftc` harness can compile it alone and check every shape of the format.
enum Citation: Hashable, Sendable {
    case text(chapter: Int, section: Int, paragraph: Int)
    /// The Preface has exactly one section, so a middle number would always be
    /// 1 and carry nothing.
    case preface(paragraph: Int)
    case lesson(number: Int, paragraph: Int)
    /// The two Workbook Part Introductions, which sit outside the 1-365 spine.
    case partIntroduction(part: Int, paragraph: Int)

    var rawValue: String {
        switch self {
        case .text(let chapter, let section, let paragraph):
            "T-\(chapter).\(section).\(paragraph)"
        case .preface(let paragraph):
            "Pref.\(paragraph)"
        case .lesson(let number, let paragraph):
            "W-\(number).\(paragraph)"
        case .partIntroduction(let part, let paragraph):
            "W-p\(part == 1 ? "I" : "II").in.\(paragraph)"
        }
    }

    /// The address without its paragraph — what a heading shows, where naming
    /// one paragraph of a whole section would be wrong.
    var stem: String {
        switch self {
        case .text(let chapter, let section, _): "T-\(chapter).\(section)"
        case .preface: "Pref"
        case .lesson(let number, _): "W-\(number)"
        case .partIntroduction(let part, _): "W-p\(part == 1 ? "I" : "II").in"
        }
    }

    var paragraph: Int {
        switch self {
        case .text(_, _, let paragraph): paragraph
        case .preface(let paragraph): paragraph
        case .lesson(_, let paragraph): paragraph
        case .partIntroduction(_, let paragraph): paragraph
        }
    }

    /// Strict. A citation missing its paragraph is not a citation, and
    /// accepting one would let a passage-level address masquerade as a precise
    /// one for the rest of the file's life.
    init?(rawValue: String) {
        func positive(_ substring: Substring) -> Int? {
            guard let value = Int(substring), value >= 1 else { return nil }
            return value
        }

        // Order matters: the Part Introductions share the "W-" prefix and must
        // be recognised before the lesson form gets a chance to mis-parse them.
        if rawValue.hasPrefix("T-") {
            let parts = rawValue.dropFirst(2).split(
                separator: ".", omittingEmptySubsequences: false
            )
            guard parts.count == 3,
                  let chapter = Int(parts[0]), chapter >= 0,
                  let section = positive(parts[1]),
                  let paragraph = positive(parts[2])
            else { return nil }
            self = .text(chapter: chapter, section: section, paragraph: paragraph)
        } else if rawValue.hasPrefix("Pref.") {
            guard let paragraph = positive(rawValue.dropFirst(5)) else { return nil }
            self = .preface(paragraph: paragraph)
        } else if rawValue.hasPrefix("W-pI.in.") {
            guard let paragraph = positive(rawValue.dropFirst(8)) else { return nil }
            self = .partIntroduction(part: 1, paragraph: paragraph)
        } else if rawValue.hasPrefix("W-pII.in.") {
            guard let paragraph = positive(rawValue.dropFirst(9)) else { return nil }
            self = .partIntroduction(part: 2, paragraph: paragraph)
        } else if rawValue.hasPrefix("W-") {
            let parts = rawValue.dropFirst(2).split(
                separator: ".", omittingEmptySubsequences: false
            )
            guard parts.count == 2,
                  let number = positive(parts[0]), number <= 365,
                  let paragraph = positive(parts[1])
            else { return nil }
            self = .lesson(number: number, paragraph: paragraph)
        } else {
            return nil
        }
    }

    /// Which paragraph a `Character` offset falls in, 1-based.
    ///
    /// `ReadingText.displayString` joins paragraphs with exactly "\n\n" and
    /// never emits a run of three, so this is a count rather than a guess.
    ///
    /// ⛔ `Character`-based, never UTF-16. Every stored highlight offset is a
    /// `Character` count, and a single emoji would shift all of them if this
    /// crossed that boundary. An offset landing between the two newlines
    /// belongs to the paragraph that just ended.
    static func paragraphNumber(atCharacterOffset offset: Int, in displayString: String) -> Int {
        guard offset > 0 else { return 1 }
        var number = 1
        var previousWasNewline = false
        var consumed = 0
        for character in displayString {
            if consumed >= offset { break }
            if character == "\n" {
                if previousWasNewline {
                    number += 1
                    previousWasNewline = false
                } else {
                    previousWasNewline = true
                }
            } else {
                previousWasNewline = false
            }
            consumed += 1
        }
        return number
    }
}
