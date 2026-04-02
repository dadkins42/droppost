import SwiftUI

struct SetupView: View {
    @EnvironmentObject var settingsVM: SettingsViewModel

    @State private var token = ""
    @State private var owner = ""
    @State private var repo = ""
    @State private var siteName = ""
    @State private var siteTagline = ""

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
                        Text("Site Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. My Family Blog", text: $siteName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Site Tagline (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Photos, Music, Adventures", text: $siteTagline)
                            .textFieldStyle(.roundedBorder)
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

                    VStack(alignment: .leading, spacing: 4) {
                        Text("GitHub Token")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        tokenField
                    }
                }
                .padding(.horizontal, 32)

                Button {
                    settingsVM.save(token: token, owner: owner, repo: repo, siteName: siteName, siteTagline: siteTagline)
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
                .disabled(token.isEmpty || owner.isEmpty || repo.isEmpty || siteName.isEmpty)

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
