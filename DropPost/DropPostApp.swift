import SwiftUI

@main
struct DropPostApp: App {
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var blogVM = BlogViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if settingsVM.isConfigured {
                    MainTabView()
                        .environmentObject(settingsVM)
                        .environmentObject(blogVM)
                        .task {
                            await blogVM.loadBlogs(using: settingsVM.gitHubService)
                        }
                } else {
                    SetupView()
                        .environmentObject(settingsVM)
                }
            }
            .preferredColorScheme(settingsVM.darkMode ? .dark : .light)
        }
    }
}
