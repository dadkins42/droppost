import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle.bold())

                Text("Last updated: April 2026")
                    .foregroundStyle(.secondary)

                section("What DropPost Does") {
                    "DropPost helps you publish blog posts to your own website hosted on GitHub Pages. You write a post, add photos, and the app uploads everything to your GitHub repository."
                }

                section("Data We Collect") {
                    "None. DropPost does not collect, store, or transmit any of your data to us or any third party. We have no servers, no analytics, and no tracking."
                }

                section("What Stays on Your Device") {
                    """
                    The following information is stored only on your device:

                    \u{2022} Your GitHub personal access token (stored in app preferences)
                    \u{2022} Your GitHub username and repository name
                    \u{2022} Your site name and tagline
                    \u{2022} App preferences like dark mode setting

                    This data never leaves your device except when communicating directly with GitHub's API to publish your posts.
                    """
                }

                section("Photos") {
                    "DropPost accesses your photo library only when you choose to add photos to a post. Selected photos are resized and uploaded only to your specified GitHub repository. No photos are sent anywhere else."
                }

                section("Location") {
                    "If you grant location permission, DropPost can tag your posts with your current location. This is entirely optional. Your location is only included in the blog post you publish — it is not sent to us or any third party."
                }

                section("GitHub API") {
                    "DropPost communicates directly with GitHub's API using your personal access token. All data goes between your device and GitHub — DropPost has no intermediary server. Your token is never shared with anyone."
                }

                section("No Accounts") {
                    "DropPost does not require you to create an account with us. The only account you need is your own GitHub account, which you manage directly with GitHub."
                }

                section("Contact") {
                    "If you have questions about this privacy policy, contact us at support@hogbodylabs.com."
                }
            }
            .padding(24)
            .frame(maxWidth: 600, alignment: .leading)
            #if os(macOS)
            .frame(maxWidth: .infinity, alignment: .center)
            #endif
        }
        #if os(iOS)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @ViewBuilder
    private func section(_ title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content())
                .foregroundStyle(.secondary)
        }
    }
}
