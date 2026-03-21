import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var showToken = false
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("GitHub Connection") {
                    HStack {
                        Text("Username")
                        Spacer()
                        Text(settingsVM.owner)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Repository")
                        Spacer()
                        Text(settingsVM.repo)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Token")
                        Spacer()
                        if showToken {
                            Text(settingsVM.token)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("••••••••")
                                .foregroundStyle(.secondary)
                        }
                        Button(showToken ? "Hide" : "Show") {
                            showToken.toggle()
                        }
                        .font(.caption)
                    }
                }

                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $settingsVM.darkMode)
                }

                Section("Website") {
                    Link("View Site", destination: URL(string: "https://\(settingsVM.owner).github.io/\(settingsVM.repo)/")!)
                }

                Section {
                    Button("Reset Configuration", role: .destructive) {
                        showResetConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Configuration?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    settingsVM.token = ""
                }
            } message: {
                Text("This will clear your GitHub token. You'll need to set it up again.")
            }
        }
    }
}
