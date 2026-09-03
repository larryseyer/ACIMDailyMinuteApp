import Foundation

/// Every lesson's practice cadence, from `Resources/WorkbookPractice.json`.
///
/// Read once and kept, like `WorkbookCatalog`. An empty dictionary means the
/// resource is missing or malformed, and the planner then plans nothing —
/// `tools/verify_practice_reminders.sh` decodes the same file with the same
/// type, so that cannot happen to a tree the checks have passed.
enum WorkbookPracticeCatalog {
    static let all: [Int: PracticeRecord] = {
        guard let url = Bundle.main.url(forResource: "WorkbookPractice", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([PracticeRecord].self, from: data)
        else { return [:] }
        var dict: [Int: PracticeRecord] = [:]
        for record in list {
            dict[record.lesson] = record
        }
        return dict
    }()

    static func record(for lessonNumber: Int) -> PracticeRecord? {
        all[lessonNumber]
    }
}
