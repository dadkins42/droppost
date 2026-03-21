import SwiftUI

struct BlogListView: View {
    @EnvironmentObject var blogVM: BlogViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var showNewBlog = false

    var body: some View {
        NavigationStack {
            List {
                if blogVM.isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading blogs...")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(blogVM.blogs) { blog in
                    HStack {
                        Text(blog.emoji)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(blog.title)
                                .font(.headline)
                            Text(blog.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let error = blogVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Blogs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewBlog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await blogVM.loadBlogs(using: settingsVM.gitHubService)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showNewBlog) {
                NewBlogView()
            }
        }
    }
}
