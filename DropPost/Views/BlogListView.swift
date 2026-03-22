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
                    NavigationLink(value: blog) {
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
                }

                if let error = blogVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .navigationTitle("Blogs")
            .navigationDestination(for: Blog.self) { blog in
                PostListView(blog: blog)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showNewBlog = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
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
                #if os(macOS)
                .frame(minWidth: 450, minHeight: 350)
                #endif
            }
        }
    }
}
