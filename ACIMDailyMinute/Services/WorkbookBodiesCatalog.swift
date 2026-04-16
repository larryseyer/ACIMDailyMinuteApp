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

    public static func body(for lessonNumber: Int) -> String? {
        entries[lessonNumber]
    }

    public static var isEmpty: Bool { entries.isEmpty }
}
