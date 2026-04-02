import Foundation

actor GitHubService {
    private let token: String
    private let owner: String
    private let repo: String
    private let siteName: String
    private let siteTagline: String
    private let baseURL = "https://api.github.com"

    init(token: String, owner: String, repo: String, siteName: String = "", siteTagline: String = "") {
        self.token = token
        self.owner = owner
        self.repo = repo
        self.siteName = siteName
        self.siteTagline = siteTagline
    }

    private var siteHeaderHTML: String {
        let name = siteName.isEmpty ? "My Site" : siteName
        let words = name.split(separator: " ")
        let h1: String
        if words.count >= 2 {
            let firstPart = words.dropLast().joined(separator: " ")
            let lastWord = String(words.last!)
            h1 = "\(firstPart) <span>\(lastWord)</span>"
        } else {
            h1 = name
        }
        let tagline = siteTagline.isEmpty ? "" : "<p class=\"tagline\">\(siteTagline)</p>"
        return "<h1>\(h1)</h1>\n    \(tagline)"
    }

    private var copyrightHTML: String {
        let year = Calendar.current.component(.year, from: Date())
        let name = siteName.isEmpty ? "My Site" : siteName
        return "&copy; \(year) \(name)"
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

    // Download raw file content (no size limit, good for images)
    func fetchRawFile(path: String) async throws -> Data {
        let url = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/main/\(path)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GitHubError.invalidResponse
        }
        return data
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

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        guard (200...201).contains(httpResponse.statusCode) else {
            let errorBody = String(data: responseData, encoding: .utf8) ?? "no body"
            print("GitHub API error \(httpResponse.statusCode) for \(path): \(errorBody)")
            throw GitHubError.httpError(httpResponse.statusCode, detail: errorBody)
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
          <title>\(blog.title) - \(siteName.isEmpty ? "My Site" : siteName)</title>
          <link rel="stylesheet" href="../../css/style.css">
        </head>
        <body>
          <header class="site-header">
            \(siteHeaderHTML)
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
          <footer class="site-footer">\(copyrightHTML)</footer>
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
          <title id="page-title">\(post.title) - \(siteName.isEmpty ? "My Site" : siteName)</title>
          <link rel="stylesheet" href="../../css/style.css">
        </head>
        <body>
          <header class="site-header">
            \(siteHeaderHTML)
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
          <footer class="site-footer">\(copyrightHTML)</footer>
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
        let path = "blogs/\(blogSlug)/\(filename)"
        // Check if file already exists (need SHA to update)
        var existingSHA: String?
        if let (_, sha) = try? await fetchFile(path: path) {
            existingSHA = sha
        }
        try await createOrUpdateFile(
            path: path,
            content: data,
            message: existingSHA != nil ? "Update image: \(filename)" : "Upload image: \(filename)",
            sha: existingSHA
        )
    }

    // MARK: - Publish Post (full flow — legacy, separate commits)

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

    // MARK: - Git Trees/Blobs API (Atomic Commits)

    /// A file to include in an atomic commit
    struct FileEntry {
        let path: String
        let content: Data
        let isBinary: Bool

        init(path: String, content: Data, isBinary: Bool = false) {
            self.path = path
            self.content = content
            self.isBinary = isBinary
        }
    }

    /// Create a blob in the repo. Returns the blob SHA.
    private func createBlob(content: Data, isBinary: Bool) async throws -> String {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/blobs")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let body: [String: Any]
        if isBinary {
            body = [
                "content": content.base64EncodedString(),
                "encoding": "base64"
            ]
        } else {
            body = [
                "content": String(data: content, encoding: .utf8) ?? content.base64EncodedString(),
                "encoding": isBinary ? "base64" : "utf-8"
            ]
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GitHubError.httpError(status, detail: errorBody)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let sha = json?["sha"] as? String else {
            throw GitHubError.invalidContent
        }
        return sha
    }

    /// Get the SHA of the latest commit on the default branch (main).
    private func getLatestCommitSHA(branch: String = "main") async throws -> String {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/ref/heads/\(branch)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GitHubError.httpError(status)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let obj = json?["object"] as? [String: Any],
              let sha = obj["sha"] as? String else {
            throw GitHubError.invalidContent
        }
        return sha
    }

    /// Get the tree SHA for a given commit.
    private func getCommitTreeSHA(_ commitSHA: String) async throws -> String {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/commits/\(commitSHA)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GitHubError.httpError(status)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let tree = json?["tree"] as? [String: Any],
              let sha = tree["sha"] as? String else {
            throw GitHubError.invalidContent
        }
        return sha
    }

    /// Create a new tree with the given file entries, based on an existing tree.
    private func createTree(baseTreeSHA: String, entries: [(path: String, blobSHA: String, mode: String)]) async throws -> String {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/trees")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let treeEntries: [[String: Any]] = entries.map { entry in
            [
                "path": entry.path,
                "mode": entry.mode,
                "type": "blob",
                "sha": entry.blobSHA
            ]
        }

        let body: [String: Any] = [
            "base_tree": baseTreeSHA,
            "tree": treeEntries
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GitHubError.httpError(status, detail: errorBody)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let sha = json?["sha"] as? String else {
            throw GitHubError.invalidContent
        }
        return sha
    }

    /// Create a commit pointing to the given tree.
    private func createCommit(message: String, treeSHA: String, parentSHA: String) async throws -> String {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/commits")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "message": message,
            "tree": treeSHA,
            "parents": [parentSHA]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GitHubError.httpError(status, detail: errorBody)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let sha = json?["sha"] as? String else {
            throw GitHubError.invalidContent
        }
        return sha
    }

    /// Update a branch ref to point to a new commit.
    private func updateRef(branch: String = "main", commitSHA: String) async throws {
        let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/git/refs/heads/\(branch)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "sha": commitSHA,
            "force": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw GitHubError.httpError(status, detail: errorBody)
        }
    }

    /// Commit multiple files atomically in a single commit using the Git Trees API.
    /// This prevents partial deploys where GitHub Pages builds with missing files.
    func atomicCommit(files: [FileEntry], message: String, branch: String = "main") async throws {
        // 1. Get latest commit and its tree
        let latestCommitSHA = try await getLatestCommitSHA(branch: branch)
        let baseTreeSHA = try await getCommitTreeSHA(latestCommitSHA)

        // 2. Create blobs for each file
        var treeEntries: [(path: String, blobSHA: String, mode: String)] = []
        for file in files {
            let blobSHA = try await createBlob(content: file.content, isBinary: file.isBinary)
            treeEntries.append((path: file.path, blobSHA: blobSHA, mode: "100644"))
        }

        // 3. Create new tree based on existing tree
        let newTreeSHA = try await createTree(baseTreeSHA: baseTreeSHA, entries: treeEntries)

        // 4. Create commit
        let newCommitSHA = try await createCommit(message: message, treeSHA: newTreeSHA, parentSHA: latestCommitSHA)

        // 5. Update branch ref
        try await updateRef(branch: branch, commitSHA: newCommitSHA)
    }

    // MARK: - Atomic Publish Post

    /// Publish a post with all its files (images, HTML, posts.json) in a single atomic commit.
    /// This ensures GitHub Pages always deploys with all files present.
    func atomicPublishPost(_ post: Post, to blogSlug: String, imageData: [(filename: String, data: Data)],
                           postHTML: String, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        var files: [FileEntry] = []

        // 1. Add image blobs
        for (index, image) in imageData.enumerated() {
            progressCallback?("Preparing image \(index + 1) of \(imageData.count)...")
            let path = "blogs/\(blogSlug)/\(image.filename)"
            files.append(FileEntry(path: path, content: image.data, isBinary: true))
        }

        // 2. Add post HTML page
        progressCallback?("Preparing post page...")
        let htmlPath = "blogs/\(blogSlug)/\(post.slug).html"
        files.append(FileEntry(path: htmlPath, content: Data(postHTML.utf8)))

        // 3. Fetch current posts.json, add the new post, include updated version
        progressCallback?("Preparing blog data...")
        let (existingPosts, _) = try await fetchPosts(blogSlug: blogSlug)
        var updatedPosts = existingPosts
        updatedPosts.posts.insert(post, at: 0)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let postsData = try encoder.encode(updatedPosts)
        files.append(FileEntry(path: "blogs/\(blogSlug)/posts.json", content: postsData))

        // 4. Commit everything atomically
        progressCallback?("Publishing...")
        try await atomicCommit(files: files, message: "New post: \(post.title)")
    }

    /// Update a post with all its files in a single atomic commit.
    func atomicUpdatePost(_ post: Post, blogSlug: String, allPosts: [Post],
                          newImageData: [(filename: String, data: Data)],
                          postHTML: String, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        var files: [FileEntry] = []

        // 1. Add new image blobs
        for (index, image) in newImageData.enumerated() {
            progressCallback?("Preparing image \(index + 1) of \(newImageData.count)...")
            let path = "blogs/\(blogSlug)/\(image.filename)"
            files.append(FileEntry(path: path, content: image.data, isBinary: true))
        }

        // 2. Add updated post HTML page
        progressCallback?("Preparing post page...")
        let htmlPath = "blogs/\(blogSlug)/\(post.slug).html"
        files.append(FileEntry(path: htmlPath, content: Data(postHTML.utf8)))

        // 3. Add updated posts.json
        progressCallback?("Preparing blog data...")
        let postsManifest = PostsManifest(posts: allPosts)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let postsData = try encoder.encode(postsManifest)
        files.append(FileEntry(path: "blogs/\(blogSlug)/posts.json", content: postsData))

        // 4. Commit everything atomically
        progressCallback?("Saving...")
        try await atomicCommit(files: files, message: "Update post: \(post.title)")
    }

    // MARK: - HTML Generation

    /// Generate the HTML for a post page. Extracted so it can be used by the atomic publish flow.
    func generatePostHTML(post: Post, blogSlug: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title id="page-title">\(post.title) - \(siteName.isEmpty ? "My Site" : siteName)</title>
          <link rel="stylesheet" href="../../css/style.css">
        </head>
        <body>
          <header class="site-header">
            \(siteHeaderHTML)
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
          <footer class="site-footer">\(copyrightHTML)</footer>
          <script src="../../js/site.js"></script>
          <script>loadPost('\(blogSlug)');</script>
        </body>
        </html>
        """
    }
}

enum GitHubError: LocalizedError {
    case invalidResponse
    case httpError(Int, detail: String? = nil)
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from GitHub"
        case .httpError(let code, let detail):
            if let detail = detail {
                return "GitHub API error \(code): \(detail)"
            }
            return "GitHub API error: \(code)"
        case .invalidContent: return "Could not decode file content"
        }
    }
}
