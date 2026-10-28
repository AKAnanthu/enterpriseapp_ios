import Observation
import SwiftUI

enum AppTab: Hashable, Sendable {
    case home
    case analytics
    case notifications
    case profile
}

enum HomeRoute: Hashable {
    case allActivity
    case activity(ActivityItem)
}

enum NotificationsRoute: Hashable {
    case detail(AppNotification)
}

/// Tab selection and per-tab navigation paths for one signed-in session. A new router is created
/// for every session, so navigation state never carries over between users.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var homePath: [HomeRoute] = []
    var notificationsPath: [NotificationsRoute] = []

    func select(_ tab: AppTab) {
        selectedTab = tab
    }
}
