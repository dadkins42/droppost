import SwiftUI
import PhotosUI

struct ComposeView: View {
    @EnvironmentObject var blogVM: BlogViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @StateObject private var composeVM = ComposeViewModel()
    @FocusState private var bodyFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                // Blog Picker
                Section("Post to") {
                    if blogVM.blogs.isEmpty {
                        Text("No blogs yet. Create one in the Blogs tab.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Blog", selection: $blogVM.selectedBlog) {
                            ForEach(blogVM.blogs) { blog in
                                Text("\(blog.emoji) \(blog.title)")
                                    .tag(Optional(blog))
                            }
                        }
                    }
                }

                // Title
                Section("Title") {
                    TextField("What happened today?", text: $composeVM.title)
                        .font(.headline)
                }

                // Body
                Section("Story") {
                    TextEditor(text: $composeVM.body)
                        .frame(minHeight: 200)
                        .focused($bodyFocused)
                }

                // Photos
                Section("Photos") {
                    PhotosPicker(
                        selection: $composeVM.selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Add Photos", systemImage: "photo.on.rectangle.angled")
                    }
                    .onChange(of: composeVM.selectedPhotos) {
                        Task {
                            await composeVM.loadImages()
                        }
                    }

                    if !composeVM.loadedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(composeVM.loadedImages.enumerated()), id: \.element.id) { index, img in
                                    VStack(spacing: 4) {
                                        ZStack(alignment: .topTrailing) {
                                            platformImage(img.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button {
                                                composeVM.removeImage(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white)
                                                    .background(Circle().fill(.black.opacity(0.5)))
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

                // YouTube (optional)
                Section("Video (optional)") {
                    youtubeField
                }

                // Error
                if let error = composeVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Post")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        bodyFocused = false
                        Task {
                            if let blog = blogVM.selectedBlog {
                                await composeVM.publish(to: blog, using: settingsVM.gitHubService)
                            }
                        }
                    } label: {
                        if composeVM.isPublishing {
                            ProgressView()
                        } else {
                            Text("Publish")
                                .bold()
                        }
                    }
                    .disabled(composeVM.isPublishing || blogVM.selectedBlog == nil)
                }

                ToolbarItem(placement: .automatic) {
                    if !composeVM.publishProgress.isEmpty {
                        Text(composeVM.publishProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if composeVM.publishSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("Published!")
                            .font(.title2.bold())
                    }
                    .padding(40)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    @ViewBuilder
    private var youtubeField: some View {
        let field = TextField("YouTube URL", text: $composeVM.youtubeURL)
        #if os(iOS)
        field
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
        #else
        field
        #endif
    }
}
