import Foundation

// ASSUMPTION: illustrative contract (Documentation/API_INTEGRATION.md), not a verified backend schema.

/// `GET /dashboard/summary`
struct DashboardSummaryDTO: Decodable, Sendable {
    let metrics: LossyArray<MetricDTO>
    let generatedAt: Date?
}

/// `GET /dashboard/activity?limit=N`
struct ActivityListDTO: Decodable, Sendable {
    let items: LossyArray<ActivityItemDTO>
}

struct ActivityItemDTO: Decodable, Sendable {
    let id: String
    let title: String
    let description: String?
    let category: String?
    let occurredAt: Date
    let status: String?
    let amount: Double?
    let currencyCode: String?
}
