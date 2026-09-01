import SwiftUI

/// What the app does with a reader's data, stated so that it is true whether or
/// not they have turned iCloud sync on.
///
/// ⛔ Three sections here were falsified the moment CloudKit became possible, and
/// all three were rewritten in the same change that added it — never afterwards.
/// **Network Requests** said nothing was sent from the device to any server.
/// **On-Device Storage** said the data never leaves the device. **Notifications**
/// said no push notification server is used, which stopped being true when the
/// app gained `aps-environment` so CloudKit could tell it another device had
/// changes. A policy that lags the code by even one release is worse than no
/// policy, because a reader has no way to tell.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                policySection(
                    title: "Data Collection",
                    body: "ACIM Daily Minute collects no data whatsoever. There are no analytics SDKs, no crash reporting services, no user accounts, no login, and no device fingerprinting. There is no server of ours anywhere in this app."
                )

                policySection(
                    title: "Network Requests",
                    body: "The app makes network requests only to www.acimdailyminute.org, to fetch daily passages, workbook lessons, audio links, and archive data. Nothing about you is sent there. Nothing is sent to any server we run, because we run none. If you turn on iCloud sync, your own highlights, notes and bookmarks travel between your devices through your Apple account."
                )

                policySection(
                    title: "On-Device Storage",
                    body: "Daily passages, lessons, archive data, and everything you make — your highlights, notes and bookmarks — are stored on your device using SwiftData, so the app works offline. This stays on your device unless you turn on iCloud sync. Even then, only what you have made travels. The cached passages, lessons and archive never leave your device at all."
                )

                policySection(
                    title: "iCloud Sync",
                    body: "Off unless you turn it on, in Settings under Your Work. When it is on, your highlights, notes and bookmarks are kept in your own iCloud private database — your Apple account, readable by you and by nobody else, including us. We cannot see it, and there is no account with us through which we could. Because it is a live sync rather than a copy, deleting a mark on one device deletes it on your others. Turning it off stops this device syncing; it does not remove what is already in your iCloud."
                )

                policySection(
                    title: "Notifications",
                    body: "Notifications are generated on your device via Background App Refresh, and their content never leaves it. We operate no push notification server. If you turn on iCloud sync, Apple may send the app a silent signal that another of your devices has changes; it carries none of your content."
                )

                policySection(
                    title: "Third-Party SDKs",
                    body: "ACIM Daily Minute includes zero third-party SDKs. No Firebase, no analytics, no ad networks, no crash reporters. Only Apple's built-in frameworks are used."
                )

                policySection(
                    title: "App Store Privacy Label",
                    body: "Data Not Collected. ACIM Daily Minute does not collect any data from users. iCloud sync does not change that: what sits in your own private database belongs to you and is not collected by the developer. The mechanism is stated here rather than left resting on the label."
                )

                // No revision date. A policy whose entire content is "nothing is
                // collected" has nothing to revise, and a stamped year makes a
                // living app look abandoned to anyone reading it a decade on.
                Text("This policy applies to every version of the app.")
                    .font(.acimCaption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(20)
            .readableContentWidth()
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
