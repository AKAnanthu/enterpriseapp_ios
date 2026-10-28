import Foundation

enum AnalyticsRange: String, CaseIterable, Identifiable, Sendable {
    case week = "7d"
    case month = "30d"
    case quarter = "90d"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: String(localized: "7 Days")
        case .month: String(localized: "30 Days")
        case .quarter: String(localized: "90 Days")
        }
    }
}

struct AnalyticsPoint: Identifiable, Hashable, Sendable {
    let date: Date
    let value: Double
    var id: Date { date }
}

struct AnalyticsSeries: Identifiable, Hashable, Sendable {
    enum Style: Sendable {
        case line, bar
    }

    let id: String
    let title: String
    let style: Style
    let points: [AnalyticsPoint]
}

struct AnalyticsOverview: Equatable, Sendable {
    let range: AnalyticsRange
    let metrics: [Metric]
    let series: [AnalyticsSeries]

    var isEmpty: Bool { metrics.isEmpty && series.allSatisfy(\.points.isEmpty) }
}

protocol AnalyticsRepository: Sendable {
    func fetchOverview(range: AnalyticsRange) async throws -> AnalyticsOverview
}
