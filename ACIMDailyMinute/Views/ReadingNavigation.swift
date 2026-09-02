import SwiftUI

/// A reading a link can open: the three refs a citation or a cross-reference
/// can resolve to. The Manual is absent because nothing has a Manual address.
enum ReadingDestination: Hashable {
    case lesson(LessonRef)
    case textSection(TextSectionRef)
    case introduction(IntroductionRef)
}

/// Pushes a reading onto whichever stack the reader is in. Installed by
/// `readingDestinations(path:)`; a link beneath a stack that never installed
/// it is a stack that forgot, and that fails where a developer can see it.
/// `Sendable` with a `@Sendable` handler because an `EnvironmentKey`'s
/// `defaultValue` is a nonisolated static, which under complete strict
/// concurrency has to be safe to touch from anywhere.
struct OpenReadingAction: Sendable {
    private let handler: @Sendable (ReadingDestination) -> Void

    init(handler: @escaping @Sendable (ReadingDestination) -> Void) {
        self.handler = handler
    }

    func callAsFunction(_ destination: ReadingDestination) {
        handler(destination)
    }
}

private struct OpenReadingKey: EnvironmentKey {
    static let defaultValue = OpenReadingAction { destination in
        assertionFailure("A reading link was tapped beneath a stack without .readingDestinations: \(destination)")
    }
}

extension EnvironmentValues {
    var openReading: OpenReadingAction {
        get { self[OpenReadingKey.self] }
        set { self[OpenReadingKey.self] = newValue }
    }
}

extension View {
    /// Declares the reading destinations on this stack and installs the action
    /// that pushes one, so a citation or a cross-reference anywhere beneath it
    /// opens in place and Back returns the reader to where they were. A tap
    /// never switches tabs.
    ///
    /// `TextSectionView`'s Previous and Next push `TextSectionRef` on their own,
    /// so that ref is declared here too, or reading onward from a linked
    /// section dead-ends.
    func readingDestinations(path: Binding<NavigationPath>) -> some View {
        self
            .navigationDestination(for: ReadingDestination.self) { destination in
                switch destination {
                case .lesson(let ref):
                    LessonDetailView(
                        lessonNumber: ref.lessonNumber,
                        spotlight: ref.spotlight,
                        presentsVideo: ref.presentsVideo
                    )
                case .textSection(let ref):
                    TextSectionView(chapter: ref.chapter, section: ref.section, spotlight: ref.spotlight)
                case .introduction(let ref):
                    WorkbookIntroductionView(lessonNumber: ref.lessonNumber, spotlight: ref.spotlight)
                }
            }
            .navigationDestination(for: TextSectionRef.self) { ref in
                TextSectionView(chapter: ref.chapter, section: ref.section, spotlight: ref.spotlight)
            }
            .environment(\.openReading, OpenReadingAction { destination in
                path.wrappedValue.append(destination)
            })
    }
}
