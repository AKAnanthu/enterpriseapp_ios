import SwiftUI

/// Shared surface treatments. Elevation is expressed with a hairline border and a very soft shadow
/// rather than heavy drop shadows; glass is reserved for system navigation chrome.
extension View {
    /// Grouped screen background that extends under the safe areas.
    func appScreenBackground() -> some View {
        background(AppColors.backgroundPrimary.ignoresSafeArea())
    }

    /// Card surface with a hairline border and subtle elevation.
    func cardSurface(cornerRadius: CGFloat = AppRadius.large) -> some View {
        background(AppColors.surfaceCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppColors.separator, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    /// Centers content with a maximum readable width on large layouts.
    func readableWidth(_ maxWidth: CGFloat = AppLayout.maxReadableWidth) -> some View {
        frame(maxWidth: maxWidth).frame(maxWidth: .infinity)
    }
}
