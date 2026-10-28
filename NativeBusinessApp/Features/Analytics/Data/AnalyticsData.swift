import Foundation

// ASSUMPTION: illustrative contract (Documentation/API_INTEGRATION.md), not a verified backend schema.

/// `GET /analytics/overview?range=30d`
struct AnalyticsOverviewDTO: Decodable, Sendable {
    let metrics: LossyArray<MetricDTO>
    let series: LossyArray<AnalyticsSeriesDTO>
}

struct AnalyticsSeriesDTO: Decodable, Sendable {
    let id: String
    let title: String
    /// `line` (default) or `bar`.
    let chartType: String?
    let points: LossyArray<AnalyticsPointDTO>
}

struct AnalyticsPointDTO: Decodable, Sendable {
    let date: Date
    let value: Double
}

enum AnalyticsEndpoints {
    enum Path {
        static let overview = "analytics/overview"
    }

    static func overview(range: AnalyticsRange) -> APIEndpoint<AnalyticsOverviewDTO> {
        APIEndpoint(path: Path.overview, queryItems: [URLQueryItem(name: "range", value: range.rawValue)])
    }
}

enum AnalyticsMapper {
    static func overview(from dto: AnalyticsOverviewDTO, range: AnalyticsRange) -> AnalyticsOverview {
        AnalyticsOverview(
            range: range,
            metrics: dto.metrics.elements.map(MetricMapper.map),
            series: dto.series.elements.map { series in
                AnalyticsSeries(
                    id: series.id,
                    title: series.title,
                    style: series.chartType?.lowercased() == "bar" ? .bar : .line,
                    points: series.points.elements
                        .filter { $0.value.isFinite }
                        .map { AnalyticsPoint(date: $0.date, value: $0.value) }
                        .sorted { $0.date < $1.date }
                )
            }
        )
    }
}

struct RemoteAnalyticsRepository: AnalyticsRepository {
    let apiClient: any APIClient

    func fetchOverview(range: AnalyticsRange) async throws -> AnalyticsOverview {
        AnalyticsMapper.overview(from: try await apiClient.send(AnalyticsEndpoints.overview(range: range)), range: range)
    }
}
