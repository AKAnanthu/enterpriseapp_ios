import Foundation

/// A generic activity entry (an order, a ticket, a transfer, …) as configured by the backend.
struct ActivityItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    /// Free-text description or category label.
    let detail: String?
    let category: String?
    let occurredAt: Date
    let status: ActivityStatus?
    /// Optional amount or metric attached to the item.
    let amount: MetricValue?
}

enum ActivityStatus: Hashable, Sendable {
    case completed
    case pending
    case failed
    /// A status the app doesn't know; shown verbatim.
    case other(String)
}

/// Dashboard KPIs.
struct DashboardSummary: Equatable, Sendable {
    let metrics: [Metric]
    let generatedAt: Date?
}
