import SwiftUI

struct NotificationsView: View {
    let viewModel: NotificationsViewModel
    @Environment(AppRouter.self) private var router
    @Environment(\.formatters) private var formatters

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.notificationsPath) {
            content
                .navigationTitle("Notifications")
                .toolbar {
                    if viewModel.unreadCount > 0 {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Mark All Read") {
                                Task { await viewModel.markAllAsRead() }
                            }
                            .accessibilityIdentifier("notifications.markAllRead")
                        }
                    }
                }
                .navigationDestination(for: NotificationsRoute.self) { route in
                    switch route {
                    case .detail(let notification):
                        NotificationDetailView(notification: notification) {
                            await viewModel.markAsRead(notification)
                        }
                    }
                }
                .appScreenBackground()
        }
        .task { await viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            LoadingView(message: "Loading notifications…")
        case .empty:
            EmptyStateView(title: "You're all caught up", message: "New notifications will appear here.", systemImage: "bell.slash")
                .accessibilityIdentifier("notifications.empty")
        case .failed(let error):
            ErrorStateView(error: error) { Task { await viewModel.load() } }
        case .loaded(let notifications):
            List {
                if let error = viewModel.actionError {
                    InlineBanner(message: error.message, style: .error, actionTitle: "Dismiss") {
                        viewModel.dismissActionError()
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                ForEach(notifications) { notification in
                    NavigationLink(value: NotificationsRoute.detail(notification)) {
                        NotificationRow(notification: notification, timestamp: formatters.timestamp(notification.createdAt))
                    }
                    .listRowBackground(AppColors.surfaceCard)
                    .swipeActions(edge: .leading) {
                        if !notification.isRead {
                            Button("Mark as Read", systemImage: "envelope.open") {
                                Task { await viewModel.markAsRead(notification) }
                            }
                            .tint(AppColors.actionFill)
                        }
                    }
                    .accessibilityIdentifier("notifications.row.\(notification.id)")
                }
            }
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.refresh() }
            .accessibilityIdentifier("notifications.list")
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let timestamp: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Circle()
                .fill(notification.isRead ? Color.clear : AppColors.actionFill)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(notification.title)
                        .font(notification.isRead ? AppTypography.body : AppTypography.bodyEmphasized)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: AppSpacing.sm)
                    Text(timestamp)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                if !notification.message.isEmpty {
                    Text(notification.message)
                        .font(AppTypography.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityValue(notification.isRead ? Text("Read") : Text("Unread"))
    }
}

struct NotificationDetailView: View {
    let notification: AppNotification
    let onAppearMarkRead: () async -> Void
    @Environment(\.formatters) private var formatters

    var body: some View {
        ScrollView {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if let category = notification.category {
                        StatusBadge(text: category, style: .neutral)
                    }
                    Text(notification.title)
                        .font(AppTypography.title)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(formatters.absolute(notification.createdAt))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(notification.message)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
            .padding(AppSpacing.lg)
            .readableWidth()
        }
        .navigationTitle("Notification")
        .navigationBarTitleDisplayMode(.inline)
        .appScreenBackground()
        .task { await onAppearMarkRead() }
        .accessibilityIdentifier("notifications.detail")
    }
}
