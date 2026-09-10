import Foundation

/// A Workbook reading that is not a numbered lesson: a Part Introduction, a
/// Review introduction, or a What Is essay. Keyed as `lesson:<id>` because
/// that is where annotations already store; the id is never 1...365.
public struct WorkbookIntroduction: Sendable, Hashable {
    public let lessonNumber: Int
    public let title: String
    public let body: String
    /// The lesson this row sits above in the Workbook spine.
    public let insertBefore: Int
    public let citationStem: String
}

public enum WorkbookBodiesCatalog {
    private struct Entry: Decodable {
        let lessonNumber: Int
        let body: String
    }

    private static let entries: [Int: String] = {
        guard let url = Bundle.main.url(forResource: "Workbook365Bodies", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Entry].self, from: data) else {
            return [:]
        }
        var dict: [Int: String] = [:]
        for entry in list {
            dict[entry.lessonNumber] = entry.body
        }
        return dict
    }()

    private struct IntroductionRecord: Decodable {
        let lessonNumber: Int
        let title: String
        let body: String
        let insertBefore: Int
        let citationStem: String
    }

    /// Workbook readings outside the 1-365 spine. They live in their own file
    /// rather than loosening `Workbook365Bodies.json`'s exact count.
    private static let introductions: [Int: WorkbookIntroduction] = {
        guard let url = Bundle.main.url(forResource: "WorkbookIntroductions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([IntroductionRecord].self, from: data)
        else { return [:] }
        var dict: [Int: WorkbookIntroduction] = [:]
        for entry in list {
            dict[entry.lessonNumber] = WorkbookIntroduction(
                lessonNumber: entry.lessonNumber,
                title: entry.title,
                body: entry.body,
                insertBefore: entry.insertBefore,
                citationStem: entry.citationStem
            )
        }
        return dict
    }()

    /// Book order: Part 1, each Review in front of its first lesson, Part 2
    /// where the Read list already puts it, then each What Is essay.
    public static let allIntroductions: [WorkbookIntroduction] = {
        introductions.values.sorted {
            ($0.insertBefore, $0.lessonNumber) < ($1.insertBefore, $1.lessonNumber)
        }
    }()

    public static func body(for lessonNumber: Int) -> String? {
        entries[lessonNumber]
    }

    public static func introduction(for lessonNumber: Int) -> WorkbookIntroduction? {
        introductions[lessonNumber]
    }

    public static func introduction(withStem stem: String) -> WorkbookIntroduction? {
        introductions.values.first { $0.citationStem == stem }
    }

    public static func isIntroduction(_ lessonNumber: Int) -> Bool {
        introductions[lessonNumber] != nil
    }

    public static var isEmpty: Bool { entries.isEmpty }
}
