import SwiftUI

/// The running head of a reading: parent name leading, citation trailing,
/// then a rule. Optional control band underneath for surfaces that still
/// pass Share and Save here rather than in the toolbar.
///
/// ⛔ **The citation never wraps.** It is the address; clipping it or
/// breaking it across lines teaches the reader the apparatus is decoration.
/// The parent may wrap at accessibility sizes — chapter titles run long.
/// `tools/verify_card_header.sh` holds both.
struct CardHeaderRow<Leading: View, Trailing: View>: View {
    private let parent: String
    private let citation: String?
    private let onOpenCitation: (() -> Void)?
    private let leading: Leading
    private let trailing: Trailing

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var parentMayWrap: Bool { dynamicTypeSize.isAccessibilitySize }

    private var showsRunningHead: Bool { !parent.isEmpty || !(citation ?? "").isEmpty }

    private var showsControls: Bool {
        Leading.self != EmptyView.self || Trailing.self != EmptyView.self
    }

    init(
        parent: String,
        citation: String? = nil,
        onOpenCitation: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.parent = parent
        self.citation = citation
        self.onOpenCitation = onOpenCitation
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsRunningHead {
                runningHead
                    .padding(.bottom, 12)
                Color.acimRule
                    .frame(height: 1)
            }

            if showsControls {
                controls
                    .padding(.top, showsRunningHead ? 12 : 0)
            }
        }
    }

    private var runningHead: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if !parent.isEmpty {
                Text(parent)
                    .font(.acimSubjectSub)
                    .foregroundStyle(.secondary)
                    .lineLimit(parentMayWrap ? nil : 1)
                    .fixedSize(horizontal: false, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            } else {
                Spacer(minLength: 0)
            }
            citationView
        }
    }

    @ViewBuilder
    private var citationView: some View {
        if let onOpenCitation, citation != nil {
            Button(action: onOpenCitation) {
                CitationLabel(raw: citation)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(citation ?? "") in the Course")
        } else {
            CitationLabel(raw: citation)
        }
    }

    @ViewBuilder
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) {
                leading
                Spacer(minLength: 4)
                trailing
            }

            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    leading
                    Spacer(minLength: 0)
                }
                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    trailing
                }
            }
        }
    }
}
