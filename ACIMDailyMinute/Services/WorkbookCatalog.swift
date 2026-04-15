import Foundation

enum WorkbookCatalog {
    private static let entries: [Int: String] = {
        guard let url = Bundle.main.url(forResource: "Workbook365", withExtension: "json") else {
            fatalError("Workbook365.json missing from main bundle")
        }
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Workbook365.json could not be read")
        }
        struct Entry: Decodable {
            let lessonNumber: Int
            let title: String
        }
        guard let list = try? JSONDecoder().decode([Entry].self, from: data) else {
            fatalError("Workbook365.json contains malformed JSON")
        }
        var dict: [Int: String] = [:]
        for entry in list {
            dict[entry.lessonNumber] = entry.title
        }
        return dict
    }()

    static func title(for lessonNumber: Int) -> String? {
        entries[lessonNumber]
    }
}
