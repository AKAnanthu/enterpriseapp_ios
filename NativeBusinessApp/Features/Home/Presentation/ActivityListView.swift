import SwiftUI
import Observation

/// Full recent-activity list.
@MainActor
@Observable
final class ActivityListViewModel {
    private(set) var state: LoadState<[ActivityItem]> = .idle
    private(set) var refreshFailure: UserFacingError?

    @ObservationIgnored private let repository: any DashboardRepository
    @ObservationIgnored private let limit: Int

    init(repository: any DashboardRepository, limit: Int = 50) {
        self.repository = repository
        self.limit = limit
    }

    func load() async {
        if state.value == nil { state = .loading }
        await fetch(isRefresh: false)
    }

    func refresh() async {
        await fetch(isRefresh: true)
    }

    private func fetch(isRefresh: Bool) async {
        do {
            state = .from(try await repository.fetchRecentActivity(limit: limit))
            refreshFailure = nil
        } catch where error.isCancellation {
            if state.isLoading { state = .idle }
        } catch {
            if isRefresh, state.value != nil {
                refreshFailure = UserFacingError(error)
            } else {
                state = .failed(UserFacingError(error))
            }
        }
    }
}

struct ActivityListView: View {
    @State private var viewModel: ActivityListViewModel
    @Environment(\.formatters) private var formatters

    init(viewModel: ActivityListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                LoadingView(message: "Loading activity…")
            case .empty:
                EmptyStateView(title: "No activity", message: "New activity will appear here.", systemImage: "tray")
                    .accessibilityIdentifier("activity.empty")
            case .failed(let error):
                ErrorStateView(error: error) { Task { await viewModel.load() } }
            case .loaded(let items):
                List {
                    if let failure = viewModel.refreshFailure {
                        InlineBanner(message: String(localized: "Couldn't refresh. \(failure.message)"))
                            .listRowSeparator(.hidden)
                    }
                    ForEach(items) { item in
                        NavigationLink(value: HomeRoute.activity(item)) {
                            ActivityRow(
                                title: item.title,
                                subtitle: item.subtitle,
                                timestamp: formatters.timestamp(item.occurredAt),
                                systemImage: item.systemImage,
                                status: item.statusDisplay,
                                trailingValue: item.amount.map(formatters.string(for:))
                            )
                        }
                        .listRowBackground(AppColors.surfaceCard)
                    }
                }
                .scrollContentBackground(.hidden)
                .refreshable { await viewModel.refresh() }
                .accessibilityIdentifier("activity.list")
            }
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .appScreenBackground()
        .task {
            if viewModel.state.value == nil { await viewModel.load() }
        }
    }
}

struct ActivityDetailView: View {
    let item: ActivityItem
    @Environment(\.formatters) private var formatters

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(item.title)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                    if let detail = item.detail {
                        Text(detail)
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let status = item.statusDisplay {
                        StatusBadge(text: status.text, style: status.style)
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
            Section("Details") {
                LabeledContent("Date", value: formatters.absolute(item.occurredAt))
                if let category = item.category {
                    LabeledContent("Category", value: category)
                }
                if let amount = item.amount {
                    LabeledContent("Amount", value: formatters.string(for: amount))
                }
                LabeledContent("Reference", value: item.id)
            }
        }
        .listRowBackground(AppColors.surfaceCard)
        .scrollContentBackground(.hidden)
        .appScreenBackground()
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("activity.detail")
    }
}
