import SwiftUI

struct NewBlogView: View {
    @EnvironmentObject var blogVM: BlogViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedEmoji = "📝"

    let emojiOptions = ["📝", "🚐", "✈️", "🏔️", "🏖️", "🎵", "📷", "🏠", "⛺", "🚗", "🛳️", "🎄"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Blog Name") {
                    TextField("e.g. Adkins Away '26", text: $title)
                        .font(.headline)
                }

                Section("Description") {
                    TextField("e.g. Our 2026 RV adventure", text: $description)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Text(emoji)
                                .font(.title)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedEmoji == emoji ? Color.orange.opacity(0.3) : Color.clear)
                                )
                                .onTapGesture {
                                    selectedEmoji = emoji
                                }
                        }
                    }
                }

                if blogVM.isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Creating blog...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = blogVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Blog")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let success = await blogVM.createBlog(
                                title: title,
                                description: description,
                                emoji: selectedEmoji,
                                using: settingsVM.gitHubService
                            )
                            if success { dismiss() }
                        }
                    }
                    .bold()
                    .disabled(title.isEmpty || blogVM.isLoading)
                }
            }
        }
    }
}
