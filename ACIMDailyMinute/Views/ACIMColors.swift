import SwiftUI

/// The app's palette, resolved by the asset catalog for each appearance.
extension Color {
    static let acimGold = Color("Gold")
    static let acimCard = Color("CardBackground")
    static let acimChip = Color("ChipBackground")
    /// Foreground for anything drawn on top of `acimGold`.
    static let acimOnGold = Color("OnGold")
}
