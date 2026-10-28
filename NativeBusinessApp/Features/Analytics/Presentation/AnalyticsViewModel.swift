import Foundation
import Observation

@MainActor
@Observable
final class AnalyticsViewModel {
    var range: AnalyticsRange = .month
    private(set) var state: LoadState<AnalyticsOverview> = .idle

    @ObservationIgnored private let repository: any AnalyticsRepository

    init(repository: any AnalyticsRepository) {
        self.repository = repository
    }

    /// Loads the selected range. The view calls this from `.task(id: range)`, so changing the range
    /// cancels the previous request before starting a new one.
    func load() async {
        let requestedRange = range
        if state.value?.range != requestedRange { state = .loading }
        do {
            let overview = try await repository.fetchOverview(range: requestedRange)
            guard requestedRange == range else { return }
            state = overview.isEmpty ? .empty : .loaded(overview)
        } catch where error.isCancellation {
            if state.isLoading { state = .idle }
        } catch {
            guard requestedRange == range else { return }
            state = .failed(UserFacingError(error))
        }
    }
}
