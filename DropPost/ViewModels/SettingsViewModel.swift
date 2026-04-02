import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @AppStorage("github_token") var token: String = ""
    @AppStorage("github_owner") var owner: String = ""
    @AppStorage("github_repo") var repo: String = ""
    @AppStorage("site_name") var siteName: String = ""
    @AppStorage("site_tagline") var siteTagline: String = ""
    @AppStorage("dark_mode") var darkMode: Bool = false

    var isConfigured: Bool {
        !token.isEmpty && !owner.isEmpty && !repo.isEmpty && !siteName.isEmpty
    }

    var gitHubService: GitHubService {
        GitHubService(token: token, owner: owner, repo: repo, siteName: siteName, siteTagline: siteTagline)
    }

    func save(token: String, owner: String, repo: String, siteName: String, siteTagline: String) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        self.repo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
        self.siteName = siteName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.siteTagline = siteTagline.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
