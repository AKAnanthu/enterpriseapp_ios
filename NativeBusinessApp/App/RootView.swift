import SwiftUI

/// Switches between launch, login, the authenticated shell and recovery screens.
struct RootView: View {
    let container: AppContainer
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let coordinator = container.coordinator
        ZStack {
            switch coordinator.route {
            case .launching:
                LaunchView()
                    .transition(.opacity)
            case .login(let notice):
                NavigationStack {
                    LoginView(
                        viewModel: container.makeLoginViewModel(),
                        notice: notice,
                        appName: container.configuration.displayName
                    )
                }
                .transition(.opacity)
            case .main(let user):
                MainTabView(container: container, user: user)
                    .id(user.id)
                    .transition(.opacity)
            case .restorationFailed(let error):
                RestorationFailedView(error: error) {
                    Task { await coordinator.retryRestoration() }
                } signOut: {
                    Task { await coordinator.abandonRestoration() }
                }
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: coordinator.route)
        .task { await coordinator.start() }
    }
}

struct LaunchView: View {
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            BrandLogo(size: 72)
            ProgressView()
                .accessibilityLabel(Text("Restoring your session"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
        .accessibilityIdentifier("launch.screen")
    }
}

/// Shown when a stored session exists but could not be validated (for example while offline).
struct RestorationFailedView: View {
    let error: UserFacingError
    let retry: () -> Void
    let signOut: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            ContentUnavailableView {
                Label(error.title, systemImage: error.systemImage)
            } description: {
                Text(error.message)
            }
            VStack(spacing: AppSpacing.md) {
                PrimaryButton("Try Again", systemImage: "arrow.clockwise", action: retry)
                    .accessibilityIdentifier("restore.retryButton")
                SecondaryButton("Sign Out", role: .destructive, action: signOut)
                    .accessibilityIdentifier("restore.signOutButton")
            }
            .readableWidth(AppLayout.maxFormWidth)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appScreenBackground()
        .accessibilityIdentifier("restore.screen")
    }
}

/// Shown instead of the app when the build configuration is invalid (for example a placeholder
/// API URL in a production build). This should only ever be seen by developers.
struct ConfigurationErrorView: View {
    let error: ConfigurationError

    var body: some View {
        ContentUnavailableView {
            Label("Configuration required", systemImage: "gearshape.2")
        } description: {
            Text(error.message)
        }
        .appScreenBackground()
        .accessibilityIdentifier("configuration.error")
    }
}
