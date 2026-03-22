import SwiftUI

struct PostListView: View {
    let blog: Blog
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var posts: [Post] = []
    @State private var postsSHA: String?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var editingPost: Post?
    @State private var showDeleteConfirm = false
    @State private var postToDelete: Post?
    @State private var isEditMode = false

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
                    if !isEditMode {
                        editingPost = post
                    }
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
            .onDelete { indexSet in
                if let index = indexSet.first {
                    postToDelete = posts[index]
                    showDeleteConfirm = true
                }
            }
            .onMove { from, to in
                posts.move(fromOffsets: from, toOffset: to)
                Task { await savePostOrder() }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(isEditMode ? .active : .inactive))
        #endif
        .navigationTitle("\(blog.emoji) \(blog.title)")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                HStack(spacing: 16) {
                    Button {
                        isEditMode.toggle()
                    } label: {
                        if isEditMode {
                            Text("Done")
                                .bold()
                        } else {
                            Image(systemName: "line.3.horizontal")
                        }
                    }

                    if !isEditMode {
                        Button {
                            Task { await loadPosts() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
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
            #if os(macOS)
            .frame(minWidth: 600, minHeight: 500)
            #endif
        }
        .alert("Delete Post?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                postToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task { await deletePost(post) }
                }
            }
        } message: {
            if let post = postToDelete {
                Text("Are you sure you want to delete \"\(post.title)\"? This cannot be undone.")
            }
        }
        .overlay {
            if isSaving {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Saving...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(30)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
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

    private func deletePost(_ post: Post) async {
        isSaving = true
        errorMessage = nil

        posts.removeAll { $0.slug == post.slug }

        do {
            let (_, freshSHA) = try await settingsVM.gitHubService.fetchPosts(blogSlug: blog.slug)
            let postsManifest = PostsManifest(posts: posts)
            try await settingsVM.gitHubService.updatePosts(postsManifest, blogSlug: blog.slug, sha: freshSHA)
            postsSHA = freshSHA
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            // Reload to get back in sync
            await loadPosts()
        }

        postToDelete = nil
        isSaving = false
    }

    private func savePostOrder() async {
        isSaving = true
        errorMessage = nil

        do {
            let (_, freshSHA) = try await settingsVM.gitHubService.fetchPosts(blogSlug: blog.slug)
            let postsManifest = PostsManifest(posts: posts)
            try await settingsVM.gitHubService.updatePosts(postsManifest, blogSlug: blog.slug, sha: freshSHA)
            postsSHA = freshSHA
        } catch {
            errorMessage = "Reorder failed: \(error.localizedDescription)"
            await loadPosts()
        }

        isSaving = false
    }
}
