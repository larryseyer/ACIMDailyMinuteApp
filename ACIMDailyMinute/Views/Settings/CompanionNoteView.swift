import SwiftUI

/// The publisher's note on what this app is for, and what it is not for.
///
/// Set in serif, like the readings rather than like the privacy policy: this is
/// a note from one student to another, not a legal notice. Emphasis is carried
/// inline through markdown in the literal strings — `Text` parses it because the
/// initializer takes a `LocalizedStringKey` — so the copy stays readable here in
/// source, which is where anyone revising it will read it.
///
/// The wording is checked against the Course. Two things it must keep doing:
/// it must not prescribe an order of study, because the Manual explicitly
/// leaves that to the student ("In some cases, it may be helpful for the pupil
/// to read the manual first. Others might do better to begin with the workbook.
/// Still others may need to start at the more abstract levels of the text."),
/// and it must let the Workbook's Introduction make the central point in its own
/// words rather than paraphrasing it.
struct CompanionNoteView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("A Note About Using ACIM Daily Minute")
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                lead

                paragraph("The Daily Minute readings are brief selections from various parts of the Course — including the Text, Workbook for Students, and Manual for Teachers — chosen to provide a moment of reflection, inspiration, and connection with its teachings.")

                paragraph("We strongly encourage students to **actually engage with the Course itself** — to practice the Workbook lessons as they are written, and to read and study the Text and the Manual for Teachers.")

                paragraph("Where to begin is left to you. The Course says that some students do best to read the Manual first, others to begin with the Workbook, and still others to start with the Text. The Workbook asks only one thing of its own pace: *do not undertake more than one lesson a day.*")

                quotation(
                    "A theoretical foundation, such as the text, is necessary as a background to make these exercises meaningful. Yet it is the exercises that will make the goal possible.",
                    source: "Workbook for Students, Introduction"
                )

                paragraph("A one-minute reading can offer a meaningful reminder, a thought to carry with you throughout the day, or an opportunity to pause and reflect. But the deeper transformation offered by *A Course in Miracles* comes through **the practice and study of the Course itself**.")

                paragraph("Please consider ACIM Daily Minute a **tool and companion for your journey with the Course** — something that can help you stay connected to its teachings throughout your day, while encouraging you to return to the Course itself for deeper study and practice.")

                closing
            }
            .padding(20)
            .readableContentWidth()
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// The thesis of the whole note, so it carries the weight of a standfirst
    /// rather than sitting in the run of paragraphs as an equal.
    private var lead: some View {
        Text("ACIM Daily Minute is intended to be a companion to *A Course in Miracles*, not a replacement for it.")
            .font(.system(.title3, design: .serif))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The same point as the lead, said plainly, and the last thing read.
    private var closing: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This app is not intended to substitute for doing the Course.")
            Text("It is intended to help support those who are doing it.")
        }
        .font(.system(.body, design: .serif).weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 4)
    }

    private func paragraph(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(.body, design: .serif))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The Course in its own voice, set apart from ours so there is never a
    /// question about which is which.
    private func quotation(_ text: String, source: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle()
                .fill(Color.primary.opacity(0.25))
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.system(.body, design: .serif).italic())
                Text(source)
                    .font(.acimCaption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        CompanionNoteView()
    }
    .preferredColorScheme(.dark)
}
