import Foundation

actor GitHubService {
    private let token: String
    private let owner: String
    private let repo: String
    private let baseURL = "https://api.github.com"

    init(token: String, owner: String, repo: String) {
        self.token = token
        self.owner = owner
        self.repo = repo
    }

    // MARK: - Read Files

    func fetchFile(path: String) async throws -> (content: Data, sha: String) {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw GitHubError.httpError(httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let contentStr = json?["content"] as? String,
              let sha = json?["sha"] as? String else {
            throw GitHubError.invalidContent
        }

        // GitHub returns base64-encoded content with newlines
        let cleanBase64 = contentStr.replacingOccurrences(of: "\n", with: "")
        guard let decodedData = Data(base64Encoded: cleanBase64) else {
            throw GitHubError.invalidContent
        }

        return (decodedData, sha)
    }

    func fetchJSON<T: Decodable>(_ type: T.Type, path: String) async throws -> (value: T, sha: String) {
        let (data, sha) = try await fetchFile(path: path)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        return (decoded, sha)
    }

    // MARK: - Write Files

    func createOrUpdateFile(path: String, content: Data, message: String, sha: String? = nil) async throws {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        var body: [String: Any] = [
            "message": message,
            "content": content.base64EncodedString()
        ]
        if let sha = sha {
            body["sha"] = sha
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        guard (200...201).contains(httpResponse.statusCode) else {
            throw GitHubError.httpError(httpResponse.statusCode)
        }
    }

    func uploadJSON<T: Encodable>(_ value: T, path: String, message: String, sha: String? = nil) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try await createOrUpdateFile(path: path, content: data, message: message, sha: sha)
    }

    // MARK: - Blog Operations

    func fetchManifest() async throws -> (manifest: BlogManifest, sha: String) {
        let result = try await fetchJSON(BlogManifest.self, path: "blogs/manifest.json")
        return (manifest: result.value, sha: result.sha)
    }

    func updateManifest(_ manifest: BlogManifest, sha: String) async throws {
        try await uploadJSON(manifest, path: "blogs/manifest.json", message: "Update blog manifest", sha: sha)
    }

    func fetchPosts(blogSlug: String) async throws -> (posts: PostsManifest, sha: String) {
        let result = try await fetchJSON(PostsManifest.self, path: "blogs/\(blogSlug)/posts.json")
        return (posts: result.value, sha: result.sha)
    }

    func updatePosts(_ posts: PostsManifest, blogSlug: String, sha: String) async throws {
        try await uploadJSON(posts, path: "blogs/\(blogSlug)/posts.json", message: "Update posts", sha: sha)
    }

    func createBlogFolder(blogSlug: String) async throws {
        let emptyPosts = PostsManifest(posts: [])
        try await uploadJSON(emptyPosts, path: "blogs/\(blogSlug)/posts.json", message: "Create blog: \(blogSlug)")
    }

    func createBlogIndexPage(blog: Blog) async throws {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>\(blog.title) - Adkins Family</title>
          <link rel="stylesheet" href="../../css/style.css">
        </head>
        <body>
          <header class="site-header">
            <h1>Adkins <span>Family</span></h1>
            <p class="tagline">Photos &bull; Music &bull; Adventures</p>
          </header>
          <nav class="site-nav">
            <a href="../../index.html">Home</a>
            <a href="../../blogs.html" class="active">Blogs</a>
          </nav>
          <main class="main-content">
            <a href="../../blogs.html" class="back-link">&larr; All Blogs</a>
            <div class="page-header">
              <h1 id="blog-title">\(blog.emoji) \(blog.title)</h1>
              <p id="blog-description">\(blog.description)</p>
            </div>
            <div class="post-list" id="post-list"></div>
          </main>
          <footer class="site-footer">&copy; 2026 Adkins Family</footer>
          <script src="../../js/site.js"></script>
          <script>loadBlogPosts('\(blog.slug)', 'post-list', 'blog-title', 'blog-description', 'page-title');</script>
        </body>
        </html>
        """
        let data = Data(html.utf8)
        try await createOrUpdateFile(path: "blogs/\(blog.slug)/index.html", content: data, message: "Create blog index: \(blog.title)")
    }

    func createPostPage(post: Post, blogSlug: String) async throws {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title id="page-title">\(post.title) - Adkins Family</title>
          <link rel="stylesheet" href="../../css/style.css">
        </head>
        <body>
          <header class="site-header">
            <h1>Adkins <span>Family</span></h1>
            <p class="tagline">Photos &bull; Music &bull; Adventures</p>
          </header>
          <nav class="site-nav">
            <a href="../../index.html">Home</a>
            <a href="../../blogs.html" class="active">Blogs</a>
          </nav>
          <main class="main-content">
            <a id="back-link" href="index.html" class="back-link">&larr; Back to blog</a>
            <article>
              <div class="post-header">
                <h1 id="post-title">\(post.title)</h1>
                <div class="post-meta">
                  <span id="post-date"></span>
                  <span id="post-location"></span>
                </div>
              </div>
              <div class="post-content" id="post-content"></div>
            </article>
          </main>
          <footer class="site-footer">&copy; 2026 Adkins Family</footer>
          <script src="../../js/site.js"></script>
          <script>loadPost('\(blogSlug)');</script>
        </body>
        </html>
        """
        let data = Data(html.utf8)
        let path = "blogs/\(blogSlug)/\(post.slug).html"
        // Try to get existing SHA for updates
        var existingSHA: String?
        if let (_, sha) = try? await fetchFile(path: path) {
            existingSHA = sha
        }
        try await createOrUpdateFile(
            path: path,
            content: data,
            message: existingSHA != nil ? "Update post: \(post.title)" : "New post: \(post.title)",
            sha: existingSHA
        )
    }

    func uploadImage(data: Data, blogSlug: String, filename: String) async throws {
        try await createOrUpdateFile(
            path: "blogs/\(blogSlug)/\(filename)",
            content: data,
            message: "Upload image: \(filename)"
        )
    }

    // MARK: - Publish Post (full flow)

    func publishPost(_ post: Post, to blogSlug: String, imageData: [(filename: String, data: Data)]) async throws {
        // 1. Upload images
        for image in imageData {
            try await uploadImage(data: image.data, blogSlug: blogSlug, filename: image.filename)
        }

        // 2. Create post HTML page
        try await createPostPage(post: post, blogSlug: blogSlug)

        // 3. Update posts.json
        let (existingPosts, sha) = try await fetchPosts(blogSlug: blogSlug)
        var updatedPosts = existingPosts
        updatedPosts.posts.insert(post, at: 0)
        try await updatePosts(updatedPosts, blogSlug: blogSlug, sha: sha)
    }
}

enum GitHubError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from GitHub"
        case .httpError(let code): return "GitHub API error: \(code)"
        case .invalidContent: return "Could not decode file content"
        }
    }
}
