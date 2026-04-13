import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                policySection(
                    title: "Data Collection",
                    body: "ACIM Daily Minute collects no data whatsoever. There are no analytics SDKs, no crash reporting services, no user accounts, no login, and no device fingerprinting."
                )

                policySection(
                    title: "Network Requests",
                    body: "The app makes network requests only to www.acimdailyminute.org to fetch daily passages, workbook lessons, audio links, and archive data. No data is sent from your device to any server."
                )

                policySection(
                    title: "On-Device Storage",
                    body: "Daily passages, lessons, bookmarks, and archive data are cached on your device using SwiftData for offline access. This data never leaves your device."
                )

                policySection(
                    title: "Notifications",
                    body: "All notifications are local, generated on-device via Background App Refresh. No push notification server is used."
                )

                policySection(
                    title: "Third-Party SDKs",
                    body: "ACIM Daily Minute includes zero third-party SDKs. No Firebase, no analytics, no ad networks, no crash reporters. Only Apple's built-in frameworks are used."
                )

                policySection(
                    title: "App Store Privacy Label",
                    body: "Data Not Collected. ACIM Daily Minute does not collect any data from users."
                )

                Text("Last updated: April 2026")
                    .font(.acimCaption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .navigationTitle("Privacy Policy")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.acimHeadline)
            Text(body)
                .font(.acimBody)
                .foregroundStyle(.secondary)
        }
    }
}
