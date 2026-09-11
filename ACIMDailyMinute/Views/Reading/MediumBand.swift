import SwiftUI

/// What a reading can play, as a value the band can draw without asking
/// the store. Surfaces resolve URLs; this type only names availability.
struct ReadingMedium: Equatable {
    var title: String
    var audioURL: String = ""
    var youtubeID: String = ""
    var canCompose: Bool = false

    enum Choice: String, CaseIterable, Equatable {
        case read
        case listen
        case watch
    }

    var showsListen: Bool { !Self.trimmed(audioURL).isEmpty }
    var showsWatch: Bool { !Self.trimmed(youtubeID).isEmpty || canCompose }

    func isAvailable(_ choice: Choice) -> Bool {
        switch choice {
        case .read: true
        case .listen: showsListen
        case .watch: showsWatch
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Read / Listen / Watch, pinned at the bottom of a pushed reading.
///
/// Three equal segments always. Unavailable ones stay in place at 32%
/// opacity so the control never changes shape between passages. tvOS
/// draws nothing — Select opens `TVPlayerView`.
struct MediumBand: View {
    let medium: ReadingMedium
    var onListen: () -> Void = {}
    var onWatch: () -> Void = {}

    @State private var selection: ReadingMedium.Choice = .read
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        #if os(tvOS)
        EmptyView()
        #else
        HStack(spacing: 4) {
            ForEach(ReadingMedium.Choice.allCases, id: \.self) { choice in
                segment(choice)
            }
        }
        .padding(5)
        .frame(height: 58)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .background(Color.acimSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 29, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 29, style: .continuous)
                .stroke(Color.acimHairline, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("How to take this reading")
        #endif
    }

    #if !os(tvOS)
    private func segment(_ choice: ReadingMedium.Choice) -> some View {
        let available = medium.isAvailable(choice)
        let selected = selection == choice
        return Button {
            guard available else { return }
            selection = choice
            switch choice {
            case .read: break
            case .listen: onListen()
            case .watch: onWatch()
            }
        } label: {
            Text(label(choice))
                .font(.acimChrome)
                .foregroundStyle(selected ? Color.acimOnGold : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.acimGold)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
        }
        .buttonStyle(.plain)
        .opacity(available ? 1 : 0.32)
        .disabled(!available)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selection)
        .accessibilityLabel(label(choice))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityHint(available ? "" : "Unavailable for this reading")
    }

    private func label(_ choice: ReadingMedium.Choice) -> String {
        switch choice {
        case .read: "Read"
        case .listen: "Listen"
        case .watch: "Watch"
        }
    }
    #endif
}
