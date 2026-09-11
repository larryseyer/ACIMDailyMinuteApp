import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The redesign type scale. Every token is `Font.acimX`.
///
/// Serif is the system serif (New York), reached through a font descriptor
/// with `.serif` design. Dynamic Type is `UIFontMetrics`, not `@ScaledMetric`.
/// macOS has no Dynamic Type; the point size is the size.
extension Font {
    static var acimMasthead: Font { acimToken(size: Self.mastheadSize, serif: true, style: .title1) }
    static var acimMastheadSub: Font { acimToken(size: 12.5, serif: false, style: .caption1) }
    static var acimDisplayTitle: Font { acimToken(size: 29, serif: true, style: .title1) }
    static var acimSubject: Font { acimToken(size: 21, serif: true, style: .title3) }
    static var acimSubjectSub: Font { acimToken(size: 14, serif: true, italic: true, style: .subheadline) }
    static var acimReading: Font { acimToken(size: Self.readingSize, serif: true, style: .body) }
    static var acimReadingPushed: Font { acimToken(size: 18, serif: true, style: .body) }
    static var acimRowTitle: Font { acimToken(size: 16, serif: true, style: .callout) }
    static var acimRowSub: Font { acimToken(size: 11.5, serif: false, style: .caption2) }
    static var acimRowNumber: Font { acimToken(size: 13, serif: true, tabular: true, style: .footnote) }
    static var acimAddress: Font { acimToken(size: Self.addressSize, serif: true, style: .subheadline) }
    static var acimAddressSmall: Font { acimToken(size: 12.5, serif: true, style: .caption1) }
    static var acimCardTitle: Font { acimToken(size: 17, serif: true, weight: .medium, style: .headline) }
    static var acimCardBody: Font { acimToken(size: 15.5, serif: true, style: .callout) }
    static var acimChrome: Font { acimToken(size: 13, serif: false, weight: .medium, style: .footnote) }
    static var acimChipText: Font { acimToken(size: 11, serif: false, weight: .medium, style: .caption2) }
    static var acimGroupHeader: Font { acimToken(size: 11, serif: false, weight: .semibold, style: .caption2) }
    static var acimTabLabel: Font { acimToken(size: 10.5, serif: false, weight: .medium, style: .caption2) }

    #if os(watchOS)
    private static let mastheadSize: CGFloat = 17
    private static let readingSize: CGFloat = 15
    private static let addressSize: CGFloat = 11
    #else
    private static let mastheadSize: CGFloat = 26
    private static let readingSize: CGFloat = 19
    private static let addressSize: CGFloat = 14
    #endif

    #if canImport(UIKit)
    private static func acimToken(
        size: CGFloat,
        serif: Bool,
        italic: Bool = false,
        tabular: Bool = false,
        weight: UIFont.Weight = .regular,
        style: UIFont.TextStyle
    ) -> Font {
        var descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if serif, let designed = descriptor.withDesign(.serif) {
            descriptor = designed
        }
        if italic, let traits = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = traits
        }
        if tabular {
            descriptor = descriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
                ]]
            ])
        }
        let base = UIFont(descriptor: descriptor, size: size)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }
    #elseif canImport(AppKit)
    private static func acimToken(
        size: CGFloat,
        serif: Bool,
        italic: Bool = false,
        tabular: Bool = false,
        weight: NSFont.Weight = .regular,
        style: NSFont.TextStyle
    ) -> Font {
        var descriptor = NSFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if serif, let designed = descriptor.withDesign(.serif) {
            descriptor = designed
        }
        if italic {
            descriptor = descriptor.withSymbolicTraits(.italic)
        }
        if tabular {
            descriptor = descriptor.addingAttributes([
                .featureSettings: [[
                    NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                    NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
                ]]
            ])
        }
        _ = style
        let font = NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
        return Font(font)
    }
    #endif
}
