import SwiftUI

/// Centered progress indicator with an optional message.
struct LoadingView: View {
    var message: LocalizedStringKey = "Loading…"

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("state.loading")
    }
}

/// Empty content placeholder built on the native `ContentUnavailableView`.
struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var systemImage: String = "tray"
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                SecondaryButton(actionTitle, action: action)
                    .frame(maxWidth: 260)
            }
        }
        // A container element so an identifier applied by the caller lands on one queryable node.
        .accessibilityElement(children: .contain)
    }
}

/// Recoverable error placeholder with an optional retry action.
struct ErrorStateView: View {
    let error: UserFacingError
    var retry: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(error.title, systemImage: error.systemImage)
        } description: {
            Text(error.message)
        } actions: {
            if error.isRetryable, let retry {
                SecondaryButton("Try Again", systemImage: "arrow.clockwise", action: retry)
                    .frame(maxWidth: 260)
                    .accessibilityIdentifier("state.retryButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("state.error")
    }
}

/// Inline, non-blocking notice for partial failures, stale data or offline status.
struct InlineBanner: View {
    enum Style {
        case info, warning, error
    }

    let message: String
    var style: Style = .warning
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    private var tint: Color {
        switch style {
        case .info: AppColors.actionText
        case .warning: AppColors.warning
        case .error: AppColors.error
        }
    }

    private var background: Color {
        switch style {
        case .info: AppColors.surfaceMuted
        case .warning: AppColors.warningBackground
        case .error: AppColors.errorBackground
        }
    }

    private var systemImage: String {
        switch style {
        case .info: "info.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.subheadlineEmphasized)
                    .foregroundStyle(AppColors.actionText)
                    .frame(minHeight: AppLayout.minTouchTarget)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(background, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
