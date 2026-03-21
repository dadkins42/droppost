import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ComposeView()
                .tabItem {
                    Label("New Post", systemImage: "square.and.pencil")
                }

            BlogListView()
                .tabItem {
                    Label("Blogs", systemImage: "book")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .tint(.orange)
    }
}
