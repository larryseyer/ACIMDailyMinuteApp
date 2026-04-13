#if os(macOS)
import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private let versionString: String = {
        let bundle = Bundle.main
        let short = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001) // swallow background

            ScrollView {
                VStack(spacing: 20) {
                    header
                    tagline
                    missionCard
                    pillars
                    linksRow
                    footer
                }
                .padding(24)
            }

            closeButton
                .padding(12)
        }
        .frame(width: 460, height: 620)
        .background(Color(white: 0.08))
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            appIcon
                .frame(width: 112, height: 112)
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
            Text("ACIM Daily Minute")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text(versionString)
                .font(.acimCallout)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    private var appIcon: some View {
        Group {
            if let nsImage = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.15))
            }
        }
    }

    // MARK: - Tagline

    private var tagline: some View {
        VStack(spacing: 4) {
            Text("Just The Facts.")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text("No opinions. No adjectives. No interpretation.")
                .font(.acimSubheadline)
                .italic()
                .foregroundStyle(.primary.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Mission

    private var missionCard: some View {
        Text("Every fact confirmed by 2+ independent sources. Every source rated for bias and reliability. Ownership disclosed on every story.")
            .font(.acimCallout)
            .foregroundStyle(.primary.opacity(0.9))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
    }

    // MARK: - Pillars

    private var pillars: some View {
        VStack(spacing: 10) {
            pillar(icon: "shield.lefthalf.filled",
                   title: "Transparent",
                   body: "Source ratings and ownership on every fact.")
            pillar(icon: "lock.shield",
                   title: "Private",
                   body: "Zero tracking. No analytics, no accounts.")
            pillar(icon: "checkmark.seal",
                   title: "Verified",
                   body: "Corrections and retractions logged openly.")
        }
    }

    private func pillar(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.acimSubheadline)
                    .fontWeight(.semibold)
                Text(body)
                    .font(.acimCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(white: 0.13).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Links

    private var linksRow: some View {
        HStack(spacing: 8) {
            aboutLink("Website", url: "https://www.acimdailyminute.org")
            aboutLink("How It Works", url: "https://www.acimdailyminute.org/whitepaper.html")
            aboutLink("Privacy", url: "https://www.acimdailyminute.org/privacy.html")
            aboutLink("Support", url: "https://www.acimdailyminute.org/support.html")
        }
    }

    private func aboutLink(_ title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Text(title)
                .font(.acimCaption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(white: 0.18))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("“The methodology belongs to no one. It serves everyone.”")
                .font(.acimCaption)
                .italic()
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("CC-BY-SA 4.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 10)
        .padding(.horizontal, 12)
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .background(Circle().fill(Color(white: 0.08)))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
    }
}

#Preview {
    AboutView()
}
#endif
