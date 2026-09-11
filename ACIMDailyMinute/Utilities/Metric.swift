import SwiftUI

/// Spacing and radii for every platform. The multiplier is a compile-time
/// constant, so a gate can assert the values without launching the app.
///
/// ⛔ Spacing and radii only. Type scales through `ACIMType` and Dynamic Type;
/// multiplying both compounds.
enum Metric {
    #if os(tvOS)
    private static let m: CGFloat = 1.6
    #elseif os(watchOS)
    private static let m: CGFloat = 0.7
    #else
    private static let m: CGFloat = 1.0
    #endif

    static let gutter: CGFloat = 24 * m
    static let block: CGFloat = 22 * m
    static let card: CGFloat = 16 * m
    static let row: CGFloat = 13 * m
    static let tight: CGFloat = 6 * m

    static let pill: CGFloat = 19 * m
    static let sheet: CGFloat = 26 * m
    static let art: CGFloat = 20 * m
    static let bar: CGFloat = 31 * m
    static let field: CGFloat = 11 * m

    static let tapTarget: CGFloat = 44
    static let progressHairline: CGFloat = 2
    static let quoteRule: CGFloat = 2

    /// SwiftUI `.lineSpacing` is the gap, `size × (multiple − 1)`.
    static let readingGap: CGFloat = 11.8
    static let readingPushedGap: CGFloat = 18 * 0.62
    static let cardBodyGap: CGFloat = 15.5 * 0.55
    static let rowTitleGap: CGFloat = 16 * 0.35
    static let mastheadGap: CGFloat = 26 * 0.15
    static let displayTitleGap: CGFloat = 29 * 0.20
}
