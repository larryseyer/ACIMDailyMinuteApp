import SwiftUI

/// The dateline that sits in Today's content, not in the navigation chrome.
struct TodayMasthead: View {
    let date: Date
    let lessonNumber: Int?
    var ruleProgress: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(Self.dateText(date))
                .font(.acimMasthead)
                .foregroundStyle(.primary)
                .lineSpacing(Metric.mastheadGap)
            if let lessonNumber {
                Text("Day \(lessonNumber) of the Workbook")
                    .font(.acimMastheadSub)
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
            }
            Rectangle()
                .fill(Color.acimRule)
                .frame(height: 1)
                .scaleEffect(x: ruleProgress, y: 1, anchor: .leading)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: date)
    }
}

extension View {
    func todaySurfaceCard() -> some View {
        padding(Metric.card)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.acimSurface)
            .clipShape(RoundedRectangle(cornerRadius: Metric.card))
            .overlay(
                RoundedRectangle(cornerRadius: Metric.card)
                    .stroke(Color.acimHairline, lineWidth: 1)
            )
    }
}
