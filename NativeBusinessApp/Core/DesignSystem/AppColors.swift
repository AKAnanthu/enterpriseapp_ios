import SwiftUI

/// Semantic color tokens. Every token is an adaptive asset with light and dark variants
/// (see Resources/Assets.xcassets), so views never hardcode appearance-specific colors.
enum AppColors {
    // Brand
    /// Navy `#0D2232` in light mode; a light tint in dark mode so brand text stays readable.
    static let brandPrimary = Color(ColorResource.brandPrimary)
    /// Navy tile used behind the logo and avatars (stays dark in both appearances).
    static let brandSurface = Color(ColorResource.brandSurface)

    // Actions
    /// `#0E67AA` fill for primary buttons. White text on it meets WCAG AA in both appearances.
    static let actionFill = Color(ColorResource.actionFill)
    /// Action blue for links and tinted icons, lightened in dark mode for contrast.
    static let actionText = Color(ColorResource.actionText)
    static let onAction = Color(ColorResource.onAction)

    // Surfaces
    static let backgroundPrimary = Color(ColorResource.backgroundPrimary)
    static let surfaceCard = Color(ColorResource.surfaceCard)
    static let surfaceMuted = Color(ColorResource.surfaceMuted)
    static let separator = Color(ColorResource.dividerLine)

    // Text
    static let textPrimary = Color(ColorResource.textPrimary)
    static let textSecondary = Color(ColorResource.textSecondary)

    // Status
    static let success = Color(ColorResource.statusSuccess)
    static let successBackground = Color(ColorResource.statusSuccessBackground)
    static let warning = Color(ColorResource.statusWarning)
    static let warningBackground = Color(ColorResource.statusWarningBackground)
    static let error = Color(ColorResource.statusError)
    static let errorBackground = Color(ColorResource.statusErrorBackground)
}
