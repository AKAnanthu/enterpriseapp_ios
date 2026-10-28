import Foundation

/// ASSUMPTION: illustrative paths; see Documentation/API_INTEGRATION.md.
enum DashboardEndpoints {
    enum Path {
        static let summary = "dashboard/summary"
        static let activity = "dashboard/activity"
    }

    static func summary() -> APIEndpoint<DashboardSummaryDTO> {
        APIEndpoint(path: Path.summary)
    }

    static func recentActivity(limit: Int) -> APIEndpoint<ActivityListDTO> {
        APIEndpoint(path: Path.activity, queryItems: [URLQueryItem(name: "limit", value: String(limit))])
    }
}
