import SwiftUI

struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.formatters) private var formatters

    var body: some View {
        NavigationStack {
            List {
                headerSection
                detailsSection
                aboutSection
                signOutSection
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle("Profile")
            .refreshable { await viewModel.load() }
            .appConfirmationDialog(
                isPresented: $viewModel.isConfirmingSignOut,
                title: "Sign out?",
                message: "You'll need to sign in again to access your account.",
                confirmTitle: "Sign Out",
                confirmIdentifier: "profile.confirmSignOut"
            ) {
                Task { await viewModel.signOut() }
            }
            .accessibilityIdentifier("profile.screen")
        }
        .task {
            if viewModel.state.value == nil { await viewModel.load() }
        }
    }

    private var headerSection: some View {
        Section {
            HStack(spacing: AppSpacing.lg) {
                AvatarView(
                    initials: User(id: "", name: viewModel.displayName, email: nil).initials,
                    imageURL: viewModel.state.value?.avatarURL,
                    size: 64
                )
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(viewModel.displayName)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                    if let email = viewModel.displayEmail {
                        Text(email)
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(.vertical, AppSpacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("profile.header")
        }
        .listRowBackground(AppColors.surfaceCard)
    }

    @ViewBuilder
    private var detailsSection: some View {
        switch viewModel.state {
        case .idle, .loading:
            Section("Account") {
                HStack {
                    ProgressView()
                    Text("Loading profile…")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .listRowBackground(AppColors.surfaceCard)
        case .failed(let error):
            Section("Account") {
                InlineBanner(
                    message: error.message, style: .error,
                    actionTitle: error.isRetryable ? "Retry" : nil,
                    action: error.isRetryable ? { Task { await viewModel.load() } } : nil
                )
                .accessibilityIdentifier("profile.error")
            }
            .listRowBackground(Color.clear)
        case .loaded(let profile):
            Section("Account") {
                if let role = profile.role { LabeledContent("Role", value: role) }
                if let organization = profile.organization { LabeledContent("Organization", value: organization) }
                if let phone = profile.phone { LabeledContent("Phone", value: phone) }
                if let memberSince = profile.memberSince {
                    LabeledContent("Member since", value: formatters.date(memberSince))
                }
                LabeledContent("Account ID", value: profile.id)
            }
            .listRowBackground(AppColors.surfaceCard)
        case .empty:
            EmptyView()
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: viewModel.appInfo.version)
            LabeledContent("Environment", value: viewModel.appInfo.environmentName)
            if let host = viewModel.appInfo.apiHost {
                LabeledContent("Server", value: host)
            }
        }
        .listRowBackground(AppColors.surfaceCard)
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.requestSignOut()
            } label: {
                HStack {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    Spacer()
                    if viewModel.isSigningOut { ProgressView() }
                }
                .frame(minHeight: AppLayout.minTouchTarget)
            }
            .foregroundStyle(AppColors.error)
            .disabled(viewModel.isSigningOut)
            .accessibilityIdentifier("profile.signOutButton")
        }
        .listRowBackground(AppColors.surfaceCard)
    }
}
