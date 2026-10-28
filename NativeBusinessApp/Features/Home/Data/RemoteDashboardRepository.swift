import Foundation

struct RemoteDashboardRepository: DashboardRepository {
    let apiClient: any APIClient

    func fetchSummary() async throws -> DashboardSummary {
        DashboardMapper.summary(from: try await apiClient.send(DashboardEndpoints.summary()))
    }

    func fetchRecentActivity(limit: Int) async throws -> [ActivityItem] {
        DashboardMapper.activity(from: try await apiClient.send(DashboardEndpoints.recentActivity(limit: limit)))
    }
}
