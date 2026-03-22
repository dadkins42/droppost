import SwiftUI
import PhotosUI
import Photos

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
    @State private var youtubeURL: String
    @State private var isSaving = false
    @State private var saveProgress: String = ""
    @State private var errorMessage: String?
    @State private var saveSuccess = false

    // Existing images (loaded from GitHub)
    @State private var existingImages: [(filename: String, image: UIImage)] = []
    @State private var removedImageFilenames: Set<String> = []
    @State private var isLoadingImages = true

    // New images to add
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newImages: [(id: UUID, uiImage: UIImage, data: Data, dateTaken: Date?)] = []

    init(post: Post, blog: Blog, postsSHA: String?, allPosts: [Post], onSave: @escaping ([Post], String?) -> Void) {
        self.originalPost = post
        self.blog = blog
        self.postsSHA = postsSHA
        self.allPosts = allPosts
        self.onSave = onSave
        _title = State(initialValue: post.title)
        _storyText = State(initialValue: post.content)
        _location = State(initialValue: post.location ?? "")
        _youtubeURL = State(initialValue: post.videos.first ?? "")
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

                // Existing Photos
                Section("Current Photos") {
                    if isLoadingImages {
                        HStack {
                            ProgressView()
                            Text("Loading photos...")
                                .foregroundStyle(.secondary)
                        }
                    } else if existingImages.isEmpty {
                        if originalPost.images.isEmpty {
                            Text("No photos")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Could not load \(originalPost.images.count) photo(s)")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(existingImages, id: \.filename) { item in
                                    if !removedImageFilenames.contains(item.filename) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: item.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button {
                                                removedImageFilenames.insert(item.filename)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white)
                                                    .background(Circle().fill(.red.opacity(0.8)))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Add New Photos
                Section("Add Photos") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Choose Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: selectedPhotos) {
                        Task { await loadNewImages() }
                    }

                    if !newImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(newImages.enumerated()), id: \.element.id) { index, img in
                                    VStack(spacing: 4) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: img.uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button {
                                                newImages.remove(at: index)
                                                if index < selectedPhotos.count {
                                                    selectedPhotos.remove(at: index)
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white)
                                                    .background(Circle().fill(.red.opacity(0.8)))
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                        if let dateStr = ComposeViewModel.formatPhotoDate(img.dateTaken) {
                                            Text(dateStr)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Video
                Section("Video (optional)") {
                    TextField("YouTube URL", text: $youtubeURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
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
                    Button(saveSuccess ? "Done" : "Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !saveSuccess {
                        Button {
                            Task { await savePost() }
                        } label: {
                            if isSaving {
                                VStack(spacing: 2) {
                                    ProgressView()
                                    if !saveProgress.isEmpty {
                                        Text(saveProgress)
                                            .font(.caption2)
                                    }
                                }
                            } else {
                                Text("Save")
                                    .bold()
                            }
                        }
                        .disabled(isSaving)
                    }
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
            .task {
                await loadExistingImages()
            }
        }
    }

    private func loadExistingImages() async {
        isLoadingImages = true
        var loaded: [(filename: String, image: UIImage)] = []

        for filename in originalPost.images {
            do {
                let data = try await settingsVM.gitHubService.fetchRawFile(
                    path: "blogs/\(blog.slug)/\(filename)"
                )
                if let image = UIImage(data: data) {
                    loaded.append((filename: filename, image: image))
                }
            } catch {
                // Skip images that fail to load
            }
        }

        existingImages = loaded
        isLoadingImages = false
    }

    private func loadNewImages() async {
        var loaded: [(id: UUID, uiImage: UIImage, data: Data, dateTaken: Date?)] = []
        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let dateTaken = ComposeViewModel.getDateFromPickerItem(item) ?? ComposeViewModel.extractDateFromImageData(data)
                let resized = resizeImage(uiImage, maxWidth: 1200)
                if let jpegData = resized.jpegData(compressionQuality: 0.7) {
                    loaded.append((id: UUID(), uiImage: resized, data: jpegData, dateTaken: dateTaken))
                }
            }
        }
        newImages = loaded
    }

    private func savePost() async {
        guard !title.isEmpty else {
            errorMessage = "Title cannot be empty"
            return
        }

        isSaving = true
        errorMessage = nil
        saveProgress = "Preparing..."

        // Figure out final image list
        // Keep existing images that weren't removed
        var finalImageFilenames = originalPost.images.filter { !removedImageFilenames.contains($0) }

        // Upload new images
        var newImageUploads: [(filename: String, data: Data)] = []
        for (index, img) in newImages.enumerated() {
            let filename = "\(originalPost.slug)-img\(originalPost.images.count + index + 1).jpg"
            finalImageFilenames.append(filename)
            newImageUploads.append((filename: filename, data: img.data))
        }

        let excerpt = String(storyText.prefix(150)) + (storyText.count > 150 ? "..." : "")

        var videos: [String] = []
        if !youtubeURL.isEmpty {
            videos.append(youtubeURL)
        }

        var updatedPost = originalPost
        updatedPost.title = title
        updatedPost.content = storyText
        updatedPost.excerpt = excerpt
        updatedPost.location = location.isEmpty ? nil : location
        updatedPost.images = finalImageFilenames
        updatedPost.videos = videos

        // Update posts list
        var updatedPosts = allPosts
        if let index = updatedPosts.firstIndex(where: { $0.slug == originalPost.slug }) {
            updatedPosts[index] = updatedPost
        }

        do {
            // Upload new images
            for (index, upload) in newImageUploads.enumerated() {
                saveProgress = "Uploading image \(index + 1) of \(newImageUploads.count)..."
                try await settingsVM.gitHubService.uploadImage(
                    data: upload.data,
                    blogSlug: blog.slug,
                    filename: upload.filename
                )
            }

            // Update posts.json
            saveProgress = "Updating post..."
            let (_, freshSHA) = try await settingsVM.gitHubService.fetchPosts(blogSlug: blog.slug)
            let postsManifest = PostsManifest(posts: updatedPosts)
            try await settingsVM.gitHubService.updatePosts(postsManifest, blogSlug: blog.slug, sha: freshSHA)

            // Update the post HTML page
            saveProgress = "Updating page..."
            try await settingsVM.gitHubService.createPostPage(post: updatedPost, blogSlug: blog.slug)

            saveProgress = ""
            saveSuccess = true
            onSave(updatedPosts, freshSHA)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
            saveProgress = ""
            print("Edit save error: \(error)")
        }

        isSaving = false
    }

    private func resizeImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxWidth else { return image }
        let scale = maxWidth / size.width
        let newSize = CGSize(width: maxWidth, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
