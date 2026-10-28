import Charts
import SwiftUI

struct AnalyticsView: View {
    @Bindable var viewModel: AnalyticsViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Picker("Period", selection: $viewModel.range) {
                        ForEach(AnalyticsRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("analytics.rangePicker")

                    content
                }
                .padding(AppSpacing.lg)
                .readableWidth()
            }
            .refreshable { await viewModel.load() }
            .navigationTitle("Analytics")
            .appScreenBackground()
            .accessibilityIdentifier("analytics.screen")
        }
        .task(id: viewModel.range) { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: AppSpacing.md) {
                metricsGrid { ForEach(0..<2, id: \.self) { _ in MetricCardSkeleton() } }
                AppCard { SkeletonView(height: 200) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Loading analytics"))
        case .empty:
            EmptyStateView(title: "No analytics yet", message: "Data for this period will appear here once it's available.",
                           systemImage: "chart.bar.xaxis")
                .accessibilityIdentifier("analytics.empty")
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let overview):
            if !overview.metrics.isEmpty {
                metricsGrid { ForEach(overview.metrics) { MetricCard(metric: $0) } }
            }
            ForEach(overview.series) { series in
                AnalyticsChartCard(series: series)
            }
        }
    }

    private func metricsGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 160), spacing: AppSpacing.md)],
            spacing: AppSpacing.md,
            content: content
        )
    }
}

/// A single time series rendered with Swift Charts.
struct AnalyticsChartCard: View {
    let series: AnalyticsSeries
    @Environment(\.formatters) private var formatters

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(series.title)
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if series.points.isEmpty {
                    Text("No data for this period.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else {
                    chart
                        .frame(height: 200)
                        .accessibilityLabel(Text(accessibilitySummary))
                }
            }
        }
        .accessibilityIdentifier("analytics.chart.\(series.id)")
    }

    private var chart: some View {
        Chart(series.points) { point in
            switch series.style {
            case .line:
                LineMark(x: .value("Date", point.date, unit: .day), y: .value(series.title, point.value))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(AppColors.actionFill)
            case .bar:
                BarMark(x: .value("Date", point.date, unit: .day), y: .value(series.title, point.value))
                    .foregroundStyle(AppColors.actionFill)
                    .cornerRadius(3)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(AppColors.separator)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        // End padding keeps the last date label from being clipped at the trailing edge.
        .chartXScale(range: .plotDimension(startPadding: 4, endPadding: 20))
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(AppColors.separator)
                AxisValueLabel()
            }
        }
    }

    private var accessibilitySummary: String {
        let values = series.points.map(\.value)
        guard let first = series.points.first, let last = series.points.last,
              let minimum = values.min(), let maximum = values.max() else { return series.title }
        let low = minimum.formatted(.number.precision(.fractionLength(0...2)))
        let high = maximum.formatted(.number.precision(.fractionLength(0...2)))
        return String(localized: "\(series.title) chart from \(formatters.day(first.date)) to \(formatters.day(last.date)). Lowest \(low), highest \(high).")
    }
}
