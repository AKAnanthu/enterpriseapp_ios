import SwiftUI

struct HomeView: View {
    let viewModel: HomeViewModel
    let user: User
    let unreadCount: Int
    let makeActivityListViewModel: () -> ActivityListViewModel

    @Environment(AppRouter.self) private var router
    @Environment(\.formatters) private var formatters
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.homePath) {
            content
                .navigationTitle("Home")
                .toolbar { toolbarContent }
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .allActivity:
                        ActivityListView(viewModel: makeActivityListViewModel())
                    case .activity(let item):
                        ActivityDetailView(item: item)
                    }
                }
                .appScreenBackground()
        }
        .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        if let error = viewModel.fullScreenError {
            ErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    greeting
                    if let refreshFailure = viewModel.refreshFailure {
                        InlineBanner(
                            message: String(localized: "Couldn't refresh. \(refreshFailure.message)"),
                            style: .warning
                        )
                        .accessibilityIdentifier("home.refreshBanner")
                    }
                    metricsSection
                    quickActionsSection
                    activitySection
                }
                .padding(AppSpacing.lg)
                .readableWidth()
            }
            .refreshable { await viewModel.refresh() }
            .accessibilityIdentifier("home.screen")
        }
    }

    // MARK: Header

    private var greeting: some View {
        HStack(spacing: AppSpacing.md) {
            AvatarView(initials: user.initials, size: 52)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(formatters.greeting())
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                Text(user.name)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColors.brandPrimary)
                    .lineLimit(2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.greeting")
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                router.select(.notifications)
            } label: {
                Image(systemName: "bell")
                    .overlay(alignment: .topTrailing) {
                        NotificationBadge(count: unreadCount)
                            .offset(x: 10, y: -8)
                            .accessibilityHidden(true)
                    }
            }
            .accessibilityLabel(unreadCount > 0 ? Text("Notifications, \(unreadCount) unread") : Text("Notifications"))
            .accessibilityIdentifier("home.notificationsButton")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                router.select(.profile)
            } label: {
                AvatarView(initials: user.initials, size: 30)
            }
            .accessibilityLabel(Text("Profile"))
            .accessibilityIdentifier("home.profileButton")
        }
    }

    // MARK: Metrics

    private var metricColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 160), spacing: AppSpacing.md)]
    }

    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Overview")
            switch viewModel.metrics {
            case .idle, .loading:
                LazyVGrid(columns: metricColumns, spacing: AppSpacing.md) {
                    ForEach(0..<4, id: \.self) { _ in MetricCardSkeleton() }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Loading overview"))
                .accessibilityIdentifier("home.metrics.loading")
            case .loaded(let metrics):
                LazyVGrid(columns: metricColumns, spacing: AppSpacing.md) {
                    ForEach(metrics) { MetricCard(metric: $0) }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.metrics")
            case .empty:
                AppCard {
                    Text("No metrics are available yet.")
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .accessibilityIdentifier("home.metrics.empty")
            case .failed(let error):
                SectionFailureView(error: error, identifier: "home.metrics.error") {
                    Task { await viewModel.load() }
                }
            }
        }
    }

    // MARK: Quick actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(title: "Quick actions")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 150 : 76), spacing: AppSpacing.md)],
                spacing: AppSpacing.md
            ) {
                ForEach(viewModel.quickActions) { action in
                    QuickActionTile(title: action.title, systemImage: action.systemImage) {
                        perform(action)
                    }
                    .accessibilityIdentifier("home.quickAction.\(action.id)")
                }
            }
        }
    }

    private func perform(_ action: QuickAction) {
        switch action.destination {
        case .tab(let tab): router.select(tab)
        case .allActivity: router.homePath.append(.allActivity)
        }
    }

    // MARK: Activity

    @ViewBuilder
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionHeader(
                title: "Recent activity",
                actionTitle: viewModel.activity.value == nil ? nil : "See All",
                actionIdentifier: "home.activity.seeAll",
                action: { router.homePath.append(.allActivity) }
            )
            switch viewModel.activity {
            case .idle, .loading:
                AppCard(padding: AppSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in ActivityRowSkeleton() }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Loading recent activity"))
                .accessibilityIdentifier("home.activity.loading")
            case .loaded(let items):
                AppCard(padding: AppSpacing.md) {
                    VStack(spacing: 0) {
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
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.activity.row.\(item.id)")
                            if item.id != items.last?.id {
                                Divider().overlay(AppColors.separator)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("home.activity.list")
            case .empty:
                AppCard {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityHidden(true)
                        Text("No recent activity")
                            .font(AppTypography.bodyEmphasized)
                            .foregroundStyle(AppColors.textPrimary)
                        Text("New activity will appear here.")
                            .font(AppTypography.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("home.activity.empty")
            case .failed(let error):
                SectionFailureView(error: error, identifier: "home.activity.error") {
                    Task { await viewModel.load() }
                }
            }
        }
    }
}

/// Compact in-section failure with a retry action, used for partial dashboard failures.
private struct SectionFailureView: View {
    let error: UserFacingError
    let identifier: String
    let retry: () -> Void

    var body: some View {
        InlineBanner(
            message: error.message,
            style: .error,
            actionTitle: error.isRetryable ? "Retry" : nil,
            action: error.isRetryable ? retry : nil
        )
        .accessibilityIdentifier(identifier)
    }
}
