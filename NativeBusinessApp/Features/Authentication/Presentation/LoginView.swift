import SwiftUI

/// Notice shown above the login form after the previous session ended.
enum LoginNotice: Equatable, Sendable {
    case sessionExpired
}

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    let notice: LoginNotice?
    let appName: String

    @FocusState private var focusedField: LoginViewModel.Field?
    @State private var isShowingResetHelp = false
    @Environment(\.openURL) private var openURL

    init(viewModel: LoginViewModel, notice: LoginNotice?, appName: String) {
        _viewModel = State(initialValue: viewModel)
        self.notice = notice
        self.appName = appName
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                header
                banners
                form
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.xxl)
            .readableWidth(AppLayout.maxFormWidth)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .appScreenBackground()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .alert("Reset your password", isPresented: $isShowingResetHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Password reset isn't available in the app yet. Contact your administrator to reset your password.")
        }
        .onChange(of: viewModel.submissionError) { _, error in
            if let error {
                AccessibilityNotification.Announcement(error.message).post()
            }
        }
        .accessibilityIdentifier("login.screen")
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            BrandLogo(size: 56)
            Text("Welcome back")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColors.brandPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Sign in to continue to \(appName).")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.top, AppSpacing.lg)
    }

    @ViewBuilder
    private var banners: some View {
        if notice == .sessionExpired {
            InlineBanner(message: String(localized: "Your session expired. Please sign in again."), style: .info)
                .accessibilityIdentifier("login.sessionNotice")
        }
        if let environmentNotice = viewModel.environmentNotice {
            InlineBanner(message: environmentNotice, style: .warning)
                .accessibilityIdentifier("login.environmentNotice")
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            identifierField

            SecureTextField(
                title: "Password",
                text: $viewModel.password,
                isRevealed: $viewModel.isPasswordRevealed,
                prompt: Text("Enter your password"),
                error: viewModel.passwordError?.message,
                focus: $focusedField,
                field: .password,
                accessibilityIdentifier: "login.passwordField"
            )
            .onSubmit(submit)

            HStack {
                Spacer()
                Button("Forgot password?", action: forgotPassword)
                    .font(AppTypography.subheadlineEmphasized)
                    .foregroundStyle(AppColors.actionText)
                    .frame(minHeight: AppLayout.minTouchTarget)
                    .accessibilityIdentifier("login.forgotPasswordButton")
            }

            if let error = viewModel.submissionError {
                InlineBanner(message: error.message, style: .error)
                    .accessibilityIdentifier("login.errorBanner")
                    .transition(.opacity)
            }

            PrimaryButton("Sign In", isLoading: viewModel.isSubmitting, action: submit)
                .accessibilityIdentifier("login.submitButton")

            if viewModel.isSubmitting {
                Text("Signing in…")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("login.progress")
            }
        }
        .disabled(viewModel.isSubmitting)
    }

    @ViewBuilder
    private var identifierField: some View {
        switch viewModel.identifierKind {
        case .email:
            AppTextField(
                title: "Email", text: $viewModel.identifier, prompt: Text(verbatim: "name@company.com"), systemImage: "envelope",
                error: viewModel.identifierError?.message, contentType: .username, keyboardType: .emailAddress,
                focus: $focusedField, field: .identifier, accessibilityIdentifier: "login.identifierField"
            )
            .onSubmit { focusedField = .password }
        case .username:
            AppTextField(
                title: "Username", text: $viewModel.identifier, prompt: Text("Your username"), systemImage: "person",
                error: viewModel.identifierError?.message, contentType: .username,
                focus: $focusedField, field: .identifier, accessibilityIdentifier: "login.identifierField"
            )
            .onSubmit { focusedField = .password }
        }
    }

    // MARK: Actions

    private func submit() {
        guard viewModel.canSubmit else { return }
        Task {
            let invalidField = await viewModel.submit()
            focusedField = invalidField
        }
    }

    private func forgotPassword() {
        if let url = viewModel.passwordResetURL {
            openURL(url)
        } else {
            isShowingResetHelp = true
        }
    }
}
