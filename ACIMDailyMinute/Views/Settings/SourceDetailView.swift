import SwiftUI

struct SourceDetailView: View {
    let source: Source

    var body: some View {
        List {
            Section("Ratings") {
                ratingRow("Accuracy", value: source.accuracy)
                ratingRow("Bias", value: source.bias)
                ratingRow("Speed", value: source.speed)
                ratingRow("Consensus", value: source.consensus)
            }

            Section("Ownership") {
                LabeledContent("Control Type") {
                    Text(source.controlType.replacingOccurrences(of: "_", with: " ").capitalized)
                }
                LabeledContent("Owner") {
                    Text(source.owner)
                }
                if !source.ownerDisplay.isEmpty {
                    LabeledContent("Display Name") {
                        Text(source.ownerDisplay)
                    }
                }
            }
        }
        .navigationTitle(source.name)
    }

    private func ratingRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            ProgressView(value: value, total: 10)
                .frame(width: 100)
                .tint(ratingColor(value))
            Text(String(format: "%.1f", value))
                .font(.acimBody)
                .fontWeight(.bold)
                .foregroundStyle(ratingColor(value))
                .frame(width: 40, alignment: .trailing)
        }
    }

    private func ratingColor(_ value: Double) -> Color {
        if value >= 8.5 { return .green.opacity(0.8) }
        if value >= 7.0 { return .blue.opacity(0.8) }
        return .orange.opacity(0.8)
    }
}
