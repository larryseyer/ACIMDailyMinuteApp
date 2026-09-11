import SwiftUI

/// Floating tab bar. Replaces the system bar and the Mac fake-iOS bar.
///
/// Hand-built at the iOS 17 floor: inset 16, 14 from the bottom safe area,
/// height 62, radius `Metric.bar`. App target only.
struct ACIMTabBar: View {
    @Binding var selectedTab: Int

    /// 14pt inset + 62pt bar. Content that must clear the bar uses this
    /// rather than measuring UIKit.
    static let clearance: CGFloat = 76

    private struct Item: Identifiable {
        let id: Int
        let title: String
        let systemImage: String
    }

    private let items: [Item] = [
        .init(id: 0, title: "Today", systemImage: "sun.max.fill"),
        .init(id: 1, title: "Course", systemImage: "book.closed.fill"),
        .init(id: 2, title: "Saved", systemImage: "bookmark.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                tabButton(item)
            }
        }
        .frame(height: 62)
        .background(.regularMaterial.opacity(1), in: RoundedRectangle(cornerRadius: Metric.bar, style: .continuous))
        .background(Color.acimSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: Metric.bar, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Metric.bar, style: .continuous)
                .stroke(Color.acimHairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ item: Item) -> some View {
        let isSelected = selectedTab == item.id
        return Button {
            selectedTab = item.id
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 19, weight: .regular))
                Text(item.title)
                    .font(.acimTabLabel)
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.acimGold) : AnyShapeStyle(.tertiary))
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
