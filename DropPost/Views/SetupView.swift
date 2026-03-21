import SwiftUI

struct SetupView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var token = ""
    @State private var owner = "dadkins42"
    @State private var repo = "adkinsfam-site"

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("DropPost")
                        .font(.largeTitle.bold())
                    Text("Blog from your phone")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GitHub Token")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField("ghp_xxxx...", text: $token)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GitHub Username")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Username", text: $owner)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repository Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Repository", text: $repo)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                .padding(.horizontal, 32)

                Button {
                    settingsVM.save(token: token, owner: owner, repo: repo)
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)
                .disabled(token.isEmpty)

                Spacer()
                Spacer()
            }
        }
    }
}
