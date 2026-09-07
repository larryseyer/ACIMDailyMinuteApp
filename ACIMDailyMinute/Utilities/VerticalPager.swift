import Foundation

/// Where a remote's up/down arrow lands in a tall document.
///
/// ⛔ **The same arithmetic the reading `UITextView` already uses.** A
/// television scrolls by moving focus, and a SwiftUI `ScrollView` of `Text`
/// has nothing focusable inside it, so the arrow never moves a pixel. The
/// note (and any other scroller that is not a text view) has to page itself
/// by this rule, or a second copy of the step will drift and one of the two
/// will stop at the wrong place.
///
/// Returns nil at either end so the arrow can leave for Skip, Get Started,
/// Previous, Next — whatever sits beyond the scroller.
enum VerticalPager {
    static func page(
        current: CGFloat,
        contentHeight: CGFloat,
        viewportHeight: CGFloat,
        goingDown: Bool,
        lineHeight: CGFloat = 28
    ) -> CGFloat? {
        let maxY = max(0, contentHeight - viewportHeight)
        let line = max(lineHeight, 1)
        let step = max((viewportHeight * 0.8 / line).rounded(.down) * line, line)
        if goingDown {
            if current >= maxY - 1 { return nil }
            return min(current + step, maxY)
        } else {
            if current <= 1 { return nil }
            return max(current - step, 0)
        }
    }
}
