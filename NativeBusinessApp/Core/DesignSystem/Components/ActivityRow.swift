import SwiftUI

/// Reusable list row for activity-style items. Takes display-ready values so it stays
/// independent of any feature's domain model.
struct ActivityRow: View {
    let title: String
    var subtitle: String?
    let timestamp: String
    var systemImage: String = "circle.grid.2x2"
    var status: (text: String, style: StatusBadge.Style)?
    var trailingValue: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: AppSpacing.md))

        layout {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColors.actionText)
                    .frame(width: 40, height: 40)
                    .background(AppColors.surfaceMuted, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.bodyEmphasized)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                    Text(timestamp)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: AppSpacing.sm)
            }
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: AppSpacing.xs) {
                if let trailingValue {
                    Text(trailingValue)
                        .font(AppTypography.amount)
                        .foregroundStyle(AppColors.textPrimary)
                }
                if let status {
                    StatusBadge(text: status.text, style: status.style)
                }
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(minHeight: AppLayout.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
