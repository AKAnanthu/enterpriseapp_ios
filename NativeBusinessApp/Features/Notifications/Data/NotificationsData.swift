import Foundation

// ASSUMPTION: illustrative contract (Documentation/API_INTEGRATION.md), not a verified backend schema.

/// `GET /notifications`
struct NotificationListDTO: Decodable, Sendable {
    let items: LossyArray<NotificationDTO>
}

struct NotificationDTO: Decodable, Sendable {
    let id: String
    let title: String
    let message: String?
    let createdAt: Date
    let isRead: Bool?
    let category: String?
}

/// `PATCH /notifications/{id}` body.
struct NotificationUpdateDTO: Encodable, Sendable {
    let isRead: Bool
}

enum NotificationsEndpoints {
    enum Path {
        static let list = "notifications"
        static let readAll = "notifications/read-all"
        static func item(_ id: String) -> String { APIPath.make("notifications", id) }
    }

    static func list() -> APIEndpoint<NotificationListDTO> {
        APIEndpoint(path: Path.list)
    }

    static func markAsRead(id: String) -> APIEndpoint<EmptyResponse> {
        APIEndpoint(path: Path.item(id), method: .patch, body: NotificationUpdateDTO(isRead: true))
    }

    static func markAllAsRead() -> APIEndpoint<EmptyResponse> {
        APIEndpoint(path: Path.readAll, method: .post)
    }
}

enum NotificationsMapper {
    static func notifications(from dto: NotificationListDTO) -> [AppNotification] {
        var seen = Set<String>()
        return dto.items.elements
            .filter { seen.insert($0.id).inserted }
            .map { AppNotification(id: $0.id, title: $0.title, message: $0.message ?? "", createdAt: $0.createdAt,
                                   isRead: $0.isRead ?? false, category: $0.category) }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

struct RemoteNotificationsRepository: NotificationsRepository {
    let apiClient: any APIClient

    func fetchNotifications() async throws -> [AppNotification] {
        NotificationsMapper.notifications(from: try await apiClient.send(NotificationsEndpoints.list()))
    }

    func markAsRead(id: String) async throws {
        _ = try await apiClient.send(NotificationsEndpoints.markAsRead(id: id))
    }

    func markAllAsRead() async throws {
        _ = try await apiClient.send(NotificationsEndpoints.markAllAsRead())
    }
}
