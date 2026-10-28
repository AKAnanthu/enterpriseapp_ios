import SwiftUI

/// Circular avatar that loads a remote image when available and falls back to initials.
/// Remote avatars are fetched without credentials, so `imageURL` must point to a public resource.
struct AvatarView: View {
    let initials: String
    var imageURL: URL?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initialsView: some View {
        ZStack {
            AppColors.brandSurface
            Text(initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
        }
    }
}

/// Placeholder brand mark. Replace with the product's logo asset.
struct BrandLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: "chart.bar.xaxis")
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(AppColors.brandSurface, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Square, tappable quick-action tile.
struct QuickActionTile: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColors.actionText)
                    .frame(width: 44, height: 44)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppTypography.captionEmphasized)
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.vertical, AppSpacing.sm)
            .cardSurface(cornerRadius: AppRadius.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
