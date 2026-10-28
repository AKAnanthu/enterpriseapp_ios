import Foundation

/// An in-app notification delivered through the API (push notifications are out of scope).
struct AppNotification: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let message: String
    let createdAt: Date
    var isRead: Bool
    let category: String?
}

protocol NotificationsRepository: Sendable {
    func fetchNotifications() async throws -> [AppNotification]
    func markAsRead(id: String) async throws
    func markAllAsRead() async throws
}
