import Foundation
import SwiftUI

@MainActor
class BlogViewModel: ObservableObject {
    @Published var blogs: [Blog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedBlog: Blog?

    private var manifestSHA: String?

    func loadBlogs(using service: GitHubService) async {
        isLoading = true
        errorMessage = nil
        do {
            let (manifest, sha) = try await service.fetchManifest()
            self.blogs = manifest.blogs
            self.manifestSHA = sha
            if selectedBlog == nil, let first = blogs.first {
                selectedBlog = first
            }
        } catch {
            errorMessage = "Could not load blogs: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func createBlog(title: String, description: String, emoji: String, using service: GitHubService) async -> Bool {
        let slug = title.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }

        let blog = Blog(
            slug: slug,
            title: title,
            description: description,
            emoji: emoji,
            createdAt: ISO8601DateFormatter().string(from: Date()).prefix(10).description
        )

        isLoading = true
        errorMessage = nil
        do {
            // Create the blog folder with posts.json
            try await service.createBlogFolder(blogSlug: slug)

            // Create blog index page
            try await service.createBlogIndexPage(blog: blog)

            // Update manifest
            guard let sha = manifestSHA else {
                throw GitHubError.invalidContent
            }
            var manifest = BlogManifest(blogs: blogs)
            manifest.blogs.append(blog)
            try await service.updateManifest(manifest, sha: sha)

            // Reload
            await loadBlogs(using: service)
            selectedBlog = blog
            isLoading = false
            return true
        } catch {
            errorMessage = "Could not create blog: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
}
