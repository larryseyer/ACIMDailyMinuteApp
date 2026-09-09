import SwiftUI

/// Compact sheet that lets a reader jump directly to any workbook lesson 1–365.
///
/// Reports the number through `onJump` and dismisses. The parent decides what
/// that number means: on iOS it pushes the lesson; on tvOS it must wait until
/// this sheet is gone before opening the player. Opening the player from
/// inside the sheet nested two presentations and crashed
/// (ACIMDailyMinuteTV-2026-09-09-105807.ips).
///
/// Validation is strict and silent until the reader has typed something: the
/// Go button is disabled while the trimmed input isn't a valid 1…365 integer,
/// and an inline hint appears only once there's non-empty invalid text to
/// complain about.
struct JumpToLessonSheet: View {
    let onJump: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var raw: String = ""

    private var trimmed: String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsed: Int? {
        Int(trimmed)
    }

    private var isValid: Bool {
        guard let n = parsed else { return false }
        return (1...365).contains(n)
    }

    private var shouldShowHint: Bool {
        !trimmed.isEmpty && !isValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    lessonField
                    if shouldShowHint {
                        Text("Enter a number 1–365")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Enter a number between 1 and 365")
                    }
                } header: {
                    Text("Lesson number")
                } footer: {
                    Text("A Course in Miracles Workbook has 365 daily lessons.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .readableContentWidth()
            .navigationTitle("Jump to Lesson")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") { submit() }
                        .disabled(!isValid)
                }
            }
        }
        #if os(iOS) || os(tvOS)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        #endif
    }

    @ViewBuilder
    private var lessonField: some View {
        let field = TextField("1–365", text: $raw)
            // tvOS draws its own full-screen keyboard entry and has no
            // rounded-border field style; the field itself is fine there.
            #if !os(tvOS)
            .textFieldStyle(.roundedBorder)
            #endif
            .font(.title3.monospacedDigit())
            .submitLabel(.go)
            .onSubmit(submit)
            .accessibilityLabel("Lesson number, 1 to 365")

        #if os(iOS) || os(tvOS)
        field.keyboardType(.numberPad)
        #else
        field
        #endif
    }

    private func submit() {
        guard let n = parsed, (1...365).contains(n) else { return }
        onJump(n)
        dismiss()
    }
}

#Preview {
    JumpToLessonSheet { _ in }
        .preferredColorScheme(.dark)
}
