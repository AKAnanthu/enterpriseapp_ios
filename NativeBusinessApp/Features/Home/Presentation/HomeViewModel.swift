import Foundation
import Observation

/// Dashboard state. Metrics and activity load concurrently and fail independently.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var metrics: LoadState<[Metric]> = .idle
    private(set) var activity: LoadState<[ActivityItem]> = .idle
    /// Set when a pull-to-refresh fails but previously loaded content is still shown.
    private(set) var refreshFailure: UserFacingError?

    let quickActions: [QuickAction]

    @ObservationIgnored private let loadDashboard: LoadDashboardUseCase
    @ObservationIgnored private var hasLoaded = false

    init(loadDashboard: LoadDashboardUseCase, quickActions: [QuickAction] = QuickAction.defaults) {
        self.loadDashboard = loadDashboard
        self.quickActions = quickActions
    }

    /// When every section failed and nothing is cached, the whole screen shows one error.
    var fullScreenError: UserFacingError? {
        guard case .failed(let metricsError) = metrics, case .failed = activity else { return nil }
        return metricsError
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    /// Initial load and "Try Again". Shows loading placeholders for sections without content.
    func load() async {
        refreshFailure = nil
        if metrics.value == nil { metrics = .loading }
        if activity.value == nil { activity = .loading }
        apply(await loadDashboard.execute(), isRefresh: false)
    }

    /// Pull-to-refresh. Keeps existing content visible if the refresh fails.
    func refresh() async {
        apply(await loadDashboard.execute(), isRefresh: true)
    }

    private func apply(_ snapshot: DashboardSnapshot, isRefresh: Bool) {
        guard !snapshot.wasCancelled else {
            // The view disappeared mid-load; reset placeholders so the next appearance reloads.
            if metrics.isLoading { metrics = .idle }
            if activity.isLoading { activity = .idle }
            return
        }
        hasLoaded = true

        var failures: [UserFacingError] = []
        metrics = Self.resolve(snapshot.summary.map(\.metrics), current: metrics, failures: &failures)
        activity = Self.resolve(snapshot.activity, current: activity, failures: &failures)
        refreshFailure = isRefresh ? failures.first : nil
    }

    /// Successful results replace the section; a failure keeps already loaded content.
    private static func resolve<Value: Collection>(
        _ result: Result<Value, any Error>,
        current: LoadState<Value>,
        failures: inout [UserFacingError]
    ) -> LoadState<Value> {
        switch result {
        case .success(let value):
            return .from(value)
        case .failure(let error):
            let presentable = UserFacingError(error)
            if current.value != nil {
                failures.append(presentable)
                return current
            }
            return .failed(presentable)
        }
    }
}
