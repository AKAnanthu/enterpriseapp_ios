import SwiftUI

/// Placeholder block used while content loads. Shimmers unless Reduce Motion is enabled.
struct SkeletonView: View {
    var width: CGFloat?
    var height: CGFloat = 14
    var cornerRadius: CGFloat = AppRadius.small

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppColors.surfaceMuted)
            .frame(width: width, height: height)
            .shimmering()
            .accessibilityHidden(true)
    }
}

/// Skeleton matching `MetricCard`'s layout.
struct MetricCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SkeletonView(width: 90, height: 12)
            SkeletonView(width: 120, height: 24)
            SkeletonView(width: 56, height: 12)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(AppSpacing.lg)
        .cardSurface()
    }
}

/// Skeleton matching `ActivityRow`'s layout.
struct ActivityRowSkeleton: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            SkeletonView(width: 40, height: 40, cornerRadius: 20)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                SkeletonView(width: 160, height: 14)
                SkeletonView(width: 110, height: 12)
            }
            Spacer()
            SkeletonView(width: 60, height: 14)
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (isAnimating ? 0.45 : 1))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}
