import SwiftUI

struct PostListView: View {
    let blog: Blog
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var posts: [Post] = []
    @State private var postsSHA: String?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingPost: Post?

    var body: some View {
        List {
            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading posts...")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(posts) { post in
                Button {
                    editingPost = post
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        HStack {
                            Text(post.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let location = post.location {
                                Text("📍 \(location)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        if !post.excerpt.isEmpty {
                            Text(post.excerpt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        .navigationTitle("\(blog.emoji) \(blog.title)")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await loadPosts() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            await loadPosts()
        }
        .sheet(item: $editingPost) { post in
            EditPostView(post: post, blog: blog, postsSHA: postsSHA, allPosts: posts) { updatedPosts, newSHA in
                self.posts = updatedPosts
                self.postsSHA = newSHA
            }
            .environmentObject(settingsVM)
        }
    }

    private func loadPosts() async {
        isLoading = true
        errorMessage = nil
        do {
            let (postsManifest, sha) = try await settingsVM.gitHubService.fetchPosts(blogSlug: blog.slug)
            posts = postsManifest.posts.sorted { $0.date > $1.date }
            postsSHA = sha
        } catch {
            errorMessage = "Could not load posts: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
