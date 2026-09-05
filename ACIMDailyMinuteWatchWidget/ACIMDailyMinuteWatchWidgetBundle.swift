import WidgetKit
import SwiftUI

/// ⛔ The `@main` this whole target exists for. `ACIMDailyMinuteWatchWidget`
/// compiled cleanly into the watch app for months and could never appear on a
/// face, because a `Widget` reaches a watch face only from a widget-extension
/// bundle — and there was no extension and no bundle. A green build said
/// nothing about it.
///
/// No Live Activity branch: there is no watchOS port of one.
@main
struct ACIMDailyMinuteWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        ACIMDailyMinuteWatchWidget()
    }
}
