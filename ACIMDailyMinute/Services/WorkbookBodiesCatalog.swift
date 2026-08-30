import Foundation

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

    private struct Introduction: Decodable {
        let lessonNumber: Int
        let title: String
        let body: String
    }

    /// The two Part Introductions, lesson ids 0 and 500. They are Workbook
    /// readings outside the 1-365 spine, so they live in their own file rather
    /// than loosening `Workbook365Bodies.json`'s exact count.
    private static let introductions: [Int: (title: String, body: String)] = {
        guard let url = Bundle.main.url(forResource: "WorkbookIntroductions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Introduction].self, from: data)
        else { return [:] }
        var dict: [Int: (title: String, body: String)] = [:]
        for entry in list {
            dict[entry.lessonNumber] = (entry.title, entry.body)
        }
        return dict
    }()

    public static func body(for lessonNumber: Int) -> String? {
        entries[lessonNumber]
    }

    public static func introduction(for lessonNumber: Int) -> (title: String, body: String)? {
        introductions[lessonNumber]
    }

    public static var isEmpty: Bool { entries.isEmpty }
}
