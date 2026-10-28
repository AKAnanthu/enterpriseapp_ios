import Foundation
import Observation

/// Shared by the Notifications tab and the unread badges on the tab bar and Home toolbar.
@MainActor
@Observable
final class NotificationsViewModel {
    private(set) var state: LoadState<[AppNotification]> = .idle
    /// Failure of a mark-as-read action; the list itself stays visible.
    private(set) var actionError: UserFacingError?

    @ObservationIgnored private let repository: any NotificationsRepository
    @ObservationIgnored private var hasLoaded = false

    init(repository: any NotificationsRepository) {
        self.repository = repository
    }

    var unreadCount: Int {
        state.value?.count(where: { !$0.isRead }) ?? 0
    }

    /// Called by both the tab shell (for the badge) and the Notifications screen; only the first
    /// call fetches.
    func loadIfNeeded() async {
        guard !hasLoaded, !state.isLoading else { return }
        await load()
    }

    func load() async {
        if state.value == nil { state = .loading }
        await fetch()
    }

    func refresh() async {
        await fetch()
    }

    /// Optimistically marks the notification as read and rolls back if the request fails.
    func markAsRead(_ notification: AppNotification) async {
        guard !notification.isRead else { return }
        await updateReadState(ids: [notification.id]) {
            try await repository.markAsRead(id: notification.id)
        }
    }

    func markAllAsRead() async {
        let unreadIDs = Set(state.value?.filter { !$0.isRead }.map(\.id) ?? [])
        guard !unreadIDs.isEmpty else { return }
        await updateReadState(ids: unreadIDs) {
            try await repository.markAllAsRead()
        }
    }

    func dismissActionError() {
        actionError = nil
    }

    // MARK: Private

    private func fetch() async {
        do {
            state = .from(try await repository.fetchNotifications())
            hasLoaded = true
        } catch where error.isCancellation {
            if state.isLoading { state = .idle }
        } catch {
            hasLoaded = true
            if state.value == nil {
                state = .failed(UserFacingError(error))
            } else {
                actionError = UserFacingError(error)
            }
        }
    }

    private func updateReadState(ids: Set<String>, request: () async throws -> Void) async {
        actionError = nil
        setRead(true, for: ids)
        do {
            try await request()
        } catch {
            setRead(false, for: ids)
            if !error.isCancellation {
                actionError = UserFacingError(error)
            }
        }
    }

    private func setRead(_ isRead: Bool, for ids: Set<String>) {
        guard var items = state.value else { return }
        for index in items.indices where ids.contains(items[index].id) {
            items[index].isRead = isRead
        }
        state = .loaded(items)
    }
}
