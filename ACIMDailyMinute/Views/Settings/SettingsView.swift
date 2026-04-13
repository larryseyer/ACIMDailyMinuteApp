import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Settings", systemImage: "gearshape.fill")
            } description: {
                Text("Notification preferences, phrases editor, and onboarding replay arrive in Phase 3.8.")
            }
            .navigationTitle("Settings")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                #endif
            }
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
