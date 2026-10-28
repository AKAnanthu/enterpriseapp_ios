import SwiftUI

/// KPI card showing a metric's value and its change versus the previous period.
struct MetricCard: View {
    let metric: Metric
    @Environment(\.formatters) private var formatters

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(metric.title)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)

            Text(formatters.string(for: metric.value))
                .font(AppTypography.metricValue)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if let change = metric.changePercent {
                Label(formatters.change(change), systemImage: metric.trend.systemImage)
                    .font(AppTypography.captionEmphasized)
                    .foregroundStyle(trendColor)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(AppSpacing.lg)
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("metric.\(metric.id)")
    }

    private var trendColor: Color {
        switch metric.trend {
        case .up: AppColors.success
        case .down: AppColors.error
        case .flat: AppColors.textSecondary
        }
    }

    private var accessibilityText: Text {
        let value = formatters.string(for: metric.value)
        guard let change = metric.changePercent else {
            return Text("\(metric.title), \(value)")
        }
        return Text("\(metric.title), \(value), \(formatters.change(change)) versus previous period")
    }
}
