import Foundation

/// The outcome of loading the dashboard. Each section succeeds or fails independently so the
/// screen can show partial content.
struct DashboardSnapshot: Sendable {
    let summary: Result<DashboardSummary, any Error>
    let activity: Result<[ActivityItem], any Error>

    var wasCancelled: Bool {
        [summary.failure, activity.failure].contains { $0?.isCancellation == true }
    }
}

/// Loads the dashboard's independent sections concurrently.
struct LoadDashboardUseCase: Sendable {
    let repository: any DashboardRepository
    var activityLimit = 5

    func execute() async -> DashboardSnapshot {
        let repository = repository
        let limit = activityLimit
        async let summary = Self.capture { try await repository.fetchSummary() }
        async let activity = Self.capture { try await repository.fetchRecentActivity(limit: limit) }
        return await DashboardSnapshot(summary: summary, activity: activity)
    }

    private static func capture<Value: Sendable>(_ operation: @Sendable () async throws -> Value) async -> Result<Value, any Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }
}

extension Result {
    var failure: Failure? {
        if case .failure(let error) = self { return error }
        return nil
    }
}
