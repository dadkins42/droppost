import SwiftUI

struct EditPostView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    let originalPost: Post
    let blog: Blog
    let postsSHA: String?
    let allPosts: [Post]
    let onSave: ([Post], String?) -> Void

    @State private var title: String
    @State private var storyText: String
    @State private var location: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var saveSuccess = false

    init(post: Post, blog: Blog, postsSHA: String?, allPosts: [Post], onSave: @escaping ([Post], String?) -> Void) {
        self.originalPost = post
        self.blog = blog
        self.postsSHA = postsSHA
        self.allPosts = allPosts
        self.onSave = onSave
        _title = State(initialValue: post.title)
        _storyText = State(initialValue: post.content)
        _location = State(initialValue: post.location ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                        .font(.headline)
                }

                Section("Story") {
                    TextEditor(text: $storyText)
                        .frame(minHeight: 200)
                }

                Section("Location") {
                    TextField("Location", text: $location)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await savePost() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .bold()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .overlay {
                if saveSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("Saved!")
                            .font(.title2.bold())
                    }
                    .padding(40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    private func savePost() async {
        guard !title.isEmpty else {
            errorMessage = "Title cannot be empty"
            return
        }

        isSaving = true
        errorMessage = nil

        let excerpt = String(storyText.prefix(150)) + (storyText.count > 150 ? "..." : "")

        var updatedPost = originalPost
        updatedPost.title = title
        updatedPost.content = storyText
        updatedPost.excerpt = excerpt
        updatedPost.location = location.isEmpty ? nil : location

        // Update posts.json
        var updatedPosts = allPosts
        if let index = updatedPosts.firstIndex(where: { $0.slug == originalPost.slug }) {
            updatedPosts[index] = updatedPost
        }

        do {
            // Fetch fresh SHA in case it changed
            let (_, freshSHA) = try await settingsVM.gitHubService.fetchPosts(blogSlug: blog.slug)

            let postsManifest = PostsManifest(posts: updatedPosts)
            try await settingsVM.gitHubService.updatePosts(postsManifest, blogSlug: blog.slug, sha: freshSHA)

            // Also update the post HTML page
            try await settingsVM.gitHubService.createPostPage(post: updatedPost, blogSlug: blog.slug)

            saveSuccess = true
            onSave(updatedPosts, freshSHA)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
