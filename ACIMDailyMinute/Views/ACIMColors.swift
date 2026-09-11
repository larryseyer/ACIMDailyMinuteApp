import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The palette as Swift literals. Named colorsets stay in the catalogue and
/// unread: Watch and the widgets cannot see the app's assets, and duplicating
/// colorsets across catalogues has already drifted.
extension Color {
    static let acimGold = Color(acimDynamic(
        light: (0.541, 0.427, 0.102, 1),
        dark: (0.831, 0.686, 0.216, 1)
    ))
    static let acimOnGold = Color(acimDynamic(
        light: (1, 1, 1, 1),
        dark: (0, 0, 0, 1)
    ))
    static let acimInk = Color(acimDynamic(
        light: (0.914, 0.925, 0.945, 1),
        dark: (0.051, 0.075, 0.125, 1)
    ))
    static let acimSurface = Color(acimDynamic(
        light: (1, 1, 1, 1),
        dark: (0.078, 0.110, 0.169, 1)
    ))
    static let acimRaised = Color(acimDynamic(
        light: (0.875, 0.894, 0.925, 1),
        dark: (0.118, 0.157, 0.224, 1)
    ))
    static let acimRule = Color(acimDynamic(
        light: (0.541, 0.427, 0.102, 0.24),
        dark: (0.831, 0.686, 0.216, 0.20)
    ))
    static let acimHairline = Color(acimDynamic(
        light: (0, 0, 0, 0.10),
        dark: (1, 1, 1, 0.09)
    ))
    static let acimCard = Color(acimDynamic(
        light: (0.955, 0.955, 0.955, 1),
        dark: (0.110, 0.110, 0.110, 0.50)
    ))
    static let acimChip = Color(acimDynamic(
        light: (0, 0, 0, 0.06),
        dark: (1, 1, 1, 0.08)
    ))

    #if os(watchOS)
    // UIColor.systemYellow / systemBlue are unavailable on watchOS.
    static let acimMark = Color(UIColor(red: 1, green: 0.8, blue: 0, alpha: 0.28))
    static let acimFind = Color(UIColor(red: 0, green: 0.478, blue: 1, alpha: 0.22))
    #elseif canImport(UIKit)
    static let acimMark = Color(UIColor.systemYellow.withAlphaComponent(0.28))
    static let acimFind = Color(UIColor.systemBlue.withAlphaComponent(0.22))
    #elseif canImport(AppKit)
    static let acimMark = Color(NSColor.systemYellow.withAlphaComponent(0.28))
    static let acimFind = Color(NSColor.systemBlue.withAlphaComponent(0.22))
    #endif
}

extension View {
    func acimInkBackground() -> some View {
        background(Color.acimInk.ignoresSafeArea())
    }

    @ViewBuilder
    func acimInkListBackground() -> some View {
        #if os(tvOS)
        background(Color.acimInk.ignoresSafeArea())
        #else
        scrollContentBackground(.hidden)
            .background(Color.acimInk.ignoresSafeArea())
        #endif
    }
}

#if os(watchOS)
private func acimDynamic(
    light: (CGFloat, CGFloat, CGFloat, CGFloat),
    dark: (CGFloat, CGFloat, CGFloat, CGFloat)
) -> UIColor {
    // UIColor(dynamicProvider:) and userInterfaceStyle are unavailable on
    // watchOS. Dark is this app's default appearance.
    _ = light
    return UIColor(red: dark.0, green: dark.1, blue: dark.2, alpha: dark.3)
}
#elseif canImport(UIKit)
private func acimDynamic(
    light: (CGFloat, CGFloat, CGFloat, CGFloat),
    dark: (CGFloat, CGFloat, CGFloat, CGFloat)
) -> UIColor {
    UIColor { trait in
        let t = trait.userInterfaceStyle == .dark ? dark : light
        return UIColor(red: t.0, green: t.1, blue: t.2, alpha: t.3)
    }
}
#elseif canImport(AppKit)
private func acimDynamic(
    light: (CGFloat, CGFloat, CGFloat, CGFloat),
    dark: (CGFloat, CGFloat, CGFloat, CGFloat)
) -> NSColor {
    NSColor(name: nil) { appearance in
        let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let t = darkMode ? dark : light
        return NSColor(srgbRed: t.0, green: t.1, blue: t.2, alpha: t.3)
    }
}
#endif
