import SwiftUI

/// Generic card container using the shared card surface.
struct AppCard<Content: View>: View {
    var padding: CGFloat = AppSpacing.lg
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
    }
}

/// Section title with an optional trailing action such as "See All".
struct SectionHeader: View {
    let title: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var actionIdentifier: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: AppSpacing.sm)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(AppTypography.subheadlineEmphasized)
                    .foregroundStyle(AppColors.actionText)
                    .frame(minHeight: AppLayout.minTouchTarget)
                    .accessibilityIdentifier(actionIdentifier ?? "")
            }
        }
    }
}

/// Small status pill.
struct StatusBadge: View {
    enum Style: Sendable {
        case success, warning, error, neutral
    }

    let text: String
    let style: Style

    private var colors: (foreground: Color, background: Color) {
        switch style {
        case .success: (AppColors.success, AppColors.successBackground)
        case .warning: (AppColors.warning, AppColors.warningBackground)
        case .error: (AppColors.error, AppColors.errorBackground)
        case .neutral: (AppColors.textSecondary, AppColors.surfaceMuted)
        }
    }

    var body: some View {
        Text(text)
            .font(AppTypography.captionEmphasized)
            .foregroundStyle(colors.foreground)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.xxs)
            .background(colors.background, in: Capsule())
    }
}

/// Unread counter. Hidden when the count is zero.
struct NotificationBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(AppColors.onAction)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(AppColors.error, in: Capsule())
                .accessibilityLabel(Text("\(count) unread"))
        }
    }
}
