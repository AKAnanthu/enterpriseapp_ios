import Foundation

protocol DashboardRepository: Sendable {
    func fetchSummary() async throws -> DashboardSummary
    func fetchRecentActivity(limit: Int) async throws -> [ActivityItem]
}
