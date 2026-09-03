#if os(macOS)
import SwiftUI
import AppKit

/// Lets the app quit while the sheet this sits in is up.
///
/// AppKit's terminate check walks every attached sheet and, for one whose
/// window has `preventsApplicationTerminationWhenModal` on, beeps, brings the
/// sheet forward and cancels the quit: Cmd-Q, the menu item and an Apple
/// event all come back "User canceled". SwiftUI leaves the flag on for the
/// introduction and About, and off for Settings, so the switch is made here,
/// on the window the view lands in. Place it in the sheet's background.
struct QuittableSheet: NSViewRepresentable {
    func makeNSView(context: Context) -> QuittableSheetView { QuittableSheetView() }
    func updateNSView(_ nsView: QuittableSheetView, context: Context) {}
}

final class QuittableSheetView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.preventsApplicationTerminationWhenModal = false
    }
}
#endif
