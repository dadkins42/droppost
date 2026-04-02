import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var showToken = false
    @State private var showResetConfirm = false
    @State private var showPrivacyPolicy = false

    var body: some View {
        #if os(macOS)
        settingsBody
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
                    .frame(minWidth: 480, minHeight: 500)
            }
            .alert("Reset Configuration?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    settingsVM.token = ""
                }
            } message: {
                Text("This will clear your GitHub token. You'll need to set it up again.")
            }
        #else
        NavigationStack {
            settingsBody
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
        #endif
    }

    @ViewBuilder
    private var settingsBody: some View {
        #if os(macOS)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Site") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Site Name") {
                            Text(settingsVM.siteName)
                                .foregroundStyle(.secondary)
                        }
                        if !settingsVM.siteTagline.isEmpty {
                            Divider()
                            LabeledContent("Tagline") {
                                Text(settingsVM.siteTagline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("GitHub Connection") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Username") {
                            Text(settingsVM.owner)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        LabeledContent("Repository") {
                            Text(settingsVM.repo)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        LabeledContent("Token") {
                            HStack {
                                if showToken {
                                    Text(settingsVM.token)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
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
                    }
                    .padding(8)
                }

                GroupBox("Appearance") {
                    Toggle("Dark Mode", isOn: $settingsVM.darkMode)
                        .padding(8)
                }

                GroupBox("Website") {
                    Link("View Site", destination: URL(string: "https://\(settingsVM.owner).github.io/\(settingsVM.repo)/")!)
                        .padding(8)
                }

                GroupBox("About") {
                    VStack(alignment: .leading, spacing: 8) {
                        Button("Privacy Policy") {
                            showPrivacyPolicy = true
                        }
                        .padding(8)
                    }
                }

                Button("Reset Configuration", role: .destructive) {
                    showResetConfirm = true
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: 500)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        #else
        Form {
            Section("Site") {
                HStack {
                    Text("Site Name")
                    Spacer()
                    Text(settingsVM.siteName)
                        .foregroundStyle(.secondary)
                }

                if !settingsVM.siteTagline.isEmpty {
                    HStack {
                        Text("Tagline")
                        Spacer()
                        Text(settingsVM.siteTagline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

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

            Section("About") {
                NavigationLink("Privacy Policy") {
                    PrivacyPolicyView()
                }
            }

            Section {
                Button("Reset Configuration", role: .destructive) {
                    showResetConfirm = true
                }
            }
        }
        #endif
    }
}
