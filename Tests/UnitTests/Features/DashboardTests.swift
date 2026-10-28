import Foundation
import Testing
@testable import NativeBusinessApp

@Suite("Dashboard DTO mapping")
struct DashboardMappingTests {
    @Test func decodesAndMapsSummary() throws {
        let json = """
        {"metrics":[
          {"id":"tx","title":"Total transactions","value":1284,"format":"count","changePercent":6.4},
          {"id":"rev","title":"Monthly revenue","value":48250.75,"format":"currency","currencyCode":"usd"},
          {"id":"rate","title":"Rate","value":0.94,"format":"percentage"},
          {"id":"misc","title":"Other","value":3.5,"format":"unknown-format"},
          {"id":"tx","title":"Duplicate","value":1,"format":"count"}
        ],"generatedAt":"2026-01-01T00:00:00Z"}
        """
        let dto = try JSONCoding.makeDecoder().decode(DashboardSummaryDTO.self, from: Data(json.utf8))
        let summary = DashboardMapper.summary(from: dto)

        #expect(summary.metrics.map(\.id) == ["tx", "rev", "rate", "misc"])
        #expect(summary.metrics[0].value == .count(1284))
        #expect(summary.metrics[0].trend == .up)
        #expect(summary.metrics[1].value == .currency(Decimal(string: "48250.75")!, currencyCode: "USD"))
        #expect(summary.metrics[2].value == .percentage(0.94))
        #expect(summary.metrics[3].value == .number(3.5))
        #expect(summary.generatedAt == Fixtures.referenceDate)
    }

    @Test func skipsMalformedItemsInsteadOfFailingTheSection() throws {
        let json = """
        {"items":[
          {"id":"1","title":"Older","occurredAt":"2026-01-01T00:00:00Z","status":"completed","amount":10,"currencyCode":"EUR"},
          {"id":"2","title":"Missing date"},
          {"id":"3","title":"Newer","occurredAt":"2026-01-02T08:30:00.123Z","status":"weird_state"},
          {"id":"4","title":"Pending","occurredAt":"2026-01-01T12:00:00Z","status":"processing","description":"Desc"}
        ]}
        """
        let dto = try JSONCoding.makeDecoder().decode(ActivityListDTO.self, from: Data(json.utf8))
        let items = DashboardMapper.activity(from: dto)

        #expect(dto.items.droppedCount == 1)
        #expect(items.map(\.id) == ["3", "4", "1"]) // Newest first.
        #expect(items[0].status == .other("weird_state"))
        #expect(items[1].status == .pending)
        #expect(items[1].detail == "Desc")
        #expect(items[2].amount == .currency(10, currencyCode: "EUR"))
    }

    @Test(arguments: [("completed", ActivityStatus.completed), ("SUCCESS", .completed), ("pending", .pending),
                      ("in_progress", .pending), ("failed", .failed), ("canceled", .failed)])
    func mapsKnownStatuses(raw: String, expected: ActivityStatus) {
        #expect(DashboardMapper.status(from: raw) == expected)
    }

    @Test func emptyStatusIsNil() {
        #expect(DashboardMapper.status(from: " ") == nil)
    }
}

@MainActor
@Suite("HomeViewModel")
struct HomeViewModelTests {
    private func makeViewModel(_ repository: MockDashboardRepository) -> HomeViewModel {
        HomeViewModel(loadDashboard: LoadDashboardUseCase(repository: repository))
    }

    @Test func loadsBothSections() async {
        let viewModel = makeViewModel(MockDashboardRepository())
        await viewModel.load()
        #expect(viewModel.metrics == .loaded([Fixtures.metric]))
        #expect(viewModel.activity == .loaded([Fixtures.activity(id: "a1")]))
        #expect(viewModel.fullScreenError == nil)
    }

    @Test func emptyCollectionsBecomeEmptyStates() async {
        let repository = MockDashboardRepository()
        repository.update {
            $0.summary = .success(DashboardSummary(metrics: [], generatedAt: nil))
            $0.activity = .success([])
        }
        let viewModel = makeViewModel(repository)
        await viewModel.load()
        #expect(viewModel.metrics == .empty)
        #expect(viewModel.activity == .empty)
    }

    @Test func partialFailureKeepsSuccessfulSection() async {
        let repository = MockDashboardRepository()
        repository.update { $0.activity = .failure(APIError.server(statusCode: 500)) }
        let viewModel = makeViewModel(repository)
        await viewModel.load()
        #expect(viewModel.metrics.value == [Fixtures.metric])
        #expect(viewModel.activity.error?.kind == .server)
        #expect(viewModel.fullScreenError == nil)
    }

    @Test func totalFailureShowsFullScreenError() async {
        let repository = MockDashboardRepository()
        repository.update {
            $0.summary = .failure(APIError.noConnection)
            $0.activity = .failure(APIError.noConnection)
        }
        let viewModel = makeViewModel(repository)
        await viewModel.load()
        #expect(viewModel.fullScreenError?.kind == .offline)

        repository.update {
            $0.summary = .success(DashboardSummary(metrics: [Fixtures.metric], generatedAt: nil))
            $0.activity = .success([])
        }
        await viewModel.load()
        #expect(viewModel.fullScreenError == nil)
        #expect(viewModel.activity == .empty)
    }

    @Test func failedRefreshKeepsLastLoadedContent() async {
        let repository = MockDashboardRepository()
        let viewModel = makeViewModel(repository)
        await viewModel.load()

        repository.update {
            $0.summary = .failure(APIError.timeout)
            $0.activity = .failure(APIError.timeout)
        }
        await viewModel.refresh()

        #expect(viewModel.metrics.value == [Fixtures.metric])
        #expect(viewModel.activity.value == [Fixtures.activity(id: "a1")])
        #expect(viewModel.refreshFailure?.kind == .timeout)
        #expect(viewModel.fullScreenError == nil)
    }

    @Test func cancelledLoadResetsToIdleForNextAppearance() async {
        let repository = MockDashboardRepository()
        repository.update {
            $0.summary = .failure(APIError.cancelled)
            $0.activity = .failure(CancellationError())
        }
        let viewModel = makeViewModel(repository)
        await viewModel.loadIfNeeded()
        #expect(viewModel.metrics == .idle)
        #expect(viewModel.activity == .idle)

        repository.update {
            $0.summary = .success(DashboardSummary(metrics: [Fixtures.metric], generatedAt: nil))
            $0.activity = .success([])
        }
        await viewModel.loadIfNeeded()
        #expect(viewModel.metrics.value == [Fixtures.metric])
    }

    @Test func activityListKeepsContentWhenRefreshFails() async {
        let repository = MockDashboardRepository()
        let viewModel = ActivityListViewModel(repository: repository)
        await viewModel.load()
        repository.update { $0.activity = .failure(APIError.noConnection) }
        await viewModel.refresh()
        #expect(viewModel.state.value?.count == 1)
        #expect(viewModel.refreshFailure?.kind == .offline)
    }
}

@MainActor
@Suite("Notifications, Analytics and Profile view models")
struct FeatureViewModelTests {
    @Test func notificationsUnreadCountAndOptimisticMarkRead() async {
        let repository = MockNotificationsRepository()
        repository.update { $0.notifications = .success([Fixtures.notification(id: "n1"), Fixtures.notification(id: "n2", isRead: true)]) }
        let viewModel = NotificationsViewModel(repository: repository)
        await viewModel.load()
        #expect(viewModel.unreadCount == 1)

        await viewModel.markAsRead(Fixtures.notification(id: "n1"))
        #expect(viewModel.unreadCount == 0)
        #expect(repository.state.withLock { $0.markedIDs } == ["n1"])
    }

    @Test func notificationsRollBackWhenMarkReadFails() async {
        let repository = MockNotificationsRepository()
        repository.update {
            $0.notifications = .success([Fixtures.notification(id: "n1"), Fixtures.notification(id: "n2")])
            $0.markResult = .failure(APIError.server(statusCode: 500))
        }
        let viewModel = NotificationsViewModel(repository: repository)
        await viewModel.load()

        await viewModel.markAllAsRead()

        #expect(viewModel.unreadCount == 2)
        #expect(viewModel.actionError?.kind == .server)
        #expect(repository.state.withLock { $0.markAllCount } == 1)
    }

    @Test func notificationsEmptyAndErrorStates() async {
        let repository = MockNotificationsRepository()
        let viewModel = NotificationsViewModel(repository: repository)
        await viewModel.load()
        #expect(viewModel.state == .empty)

        repository.update { $0.notifications = .failure(APIError.forbidden) }
        let failing = NotificationsViewModel(repository: repository)
        await failing.load()
        #expect(failing.state.error?.kind == .accessDenied)
    }

    @Test func notificationsDecodeAndSortNewestFirst() throws {
        let json = """
        {"items":[{"id":"a","title":"Old","createdAt":"2026-01-01T00:00:00Z"},
                  {"id":"b","title":"New","message":"m","createdAt":"2026-01-02T00:00:00Z","isRead":true}]}
        """
        let dto = try JSONCoding.makeDecoder().decode(NotificationListDTO.self, from: Data(json.utf8))
        let items = NotificationsMapper.notifications(from: dto)
        #expect(items.map(\.id) == ["b", "a"])
        #expect(items[1].isRead == false)
        #expect(items[1].message == "")
    }

    @Test func analyticsLoadsSelectedRange() async throws {
        struct Repository: AnalyticsRepository {
            func fetchOverview(range: AnalyticsRange) async throws -> AnalyticsOverview {
                AnalyticsOverview(range: range, metrics: [Fixtures.metric], series: [])
            }
        }
        let viewModel = AnalyticsViewModel(repository: Repository())
        viewModel.range = .week
        await viewModel.load()
        #expect(viewModel.state.value?.range == .week)
    }

    @Test func analyticsMapperSortsPointsAndPicksStyle() throws {
        let json = """
        {"metrics":[],"series":[{"id":"s","title":"S","chartType":"bar","points":[
          {"date":"2026-01-02T00:00:00Z","value":2},{"date":"2026-01-01T00:00:00Z","value":1},{"date":"bad","value":3}]}]}
        """
        let dto = try JSONCoding.makeDecoder().decode(AnalyticsOverviewDTO.self, from: Data(json.utf8))
        let overview = AnalyticsMapper.overview(from: dto, range: .month)
        #expect(overview.series.first?.style == .bar)
        #expect(overview.series.first?.points.map(\.value) == [1, 2])
    }

    @Test func profileSignOutDelegatesToSession() async {
        struct Repository: ProfileRepository {
            func fetchProfile() async throws -> UserProfile { throw APIError.noConnection }
        }
        let session = MockSessionTerminator()
        let viewModel = ProfileViewModel(
            sessionUser: Fixtures.user, appInfo: AppInfo(version: "1.0 (1)", environmentName: "Development", apiHost: nil),
            repository: Repository(), session: session
        )
        await viewModel.load()
        #expect(viewModel.state.error?.kind == .offline)
        #expect(viewModel.displayName == Fixtures.user.name) // Falls back to the session user.

        await viewModel.signOut()
        #expect(session.logoutCount == 1)
    }

    @Test func profileMapperOnlyAcceptsHTTPSAvatars() {
        let insecure = ProfileMapper.profile(from: ProfileDTO(id: "1", name: "N", email: nil, role: nil, organization: nil,
                                                             phone: nil, memberSince: nil, avatarURL: "http://cdn.example.com/a.png"))
        let secure = ProfileMapper.profile(from: ProfileDTO(id: "1", name: "N", email: nil, role: nil, organization: nil,
                                                           phone: nil, memberSince: nil, avatarURL: "https://cdn.example.com/a.png"))
        #expect(insecure.avatarURL == nil)
        #expect(secure.avatarURL != nil)
    }
}
