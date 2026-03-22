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
                        tokenField
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GitHub Username")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ownerField
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repository Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        repoField
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

    @ViewBuilder
    private var tokenField: some View {
        let field = SecureField("ghp_xxxx...", text: $token)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
        #if os(iOS)
        field.textInputAutocapitalization(.never)
        #else
        field
        #endif
    }

    @ViewBuilder
    private var ownerField: some View {
        let field = TextField("Username", text: $owner)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
        #if os(iOS)
        field.textInputAutocapitalization(.never)
        #else
        field
        #endif
    }

    @ViewBuilder
    private var repoField: some View {
        let field = TextField("Repository", text: $repo)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
        #if os(iOS)
        field.textInputAutocapitalization(.never)
        #else
        field
        #endif
    }
}
