import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @AppStorage("github_token") var token: String = ""
    @AppStorage("github_owner") var owner: String = "dadkins42"
    @AppStorage("github_repo") var repo: String = "adkinsfam-site"
    @AppStorage("dark_mode") var darkMode: Bool = false

    var isConfigured: Bool {
        !token.isEmpty && !owner.isEmpty && !repo.isEmpty
    }

    var gitHubService: GitHubService {
        GitHubService(token: token, owner: owner, repo: repo)
    }

    func save(token: String, owner: String, repo: String) {
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.owner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
        self.repo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
