import Foundation

/// A configurable shortcut on the dashboard. Destinations are limited to screens that exist
/// in the app, so a quick action can never lead to an unimplemented feature.
struct QuickAction: Identifiable, Hashable, Sendable {
    enum Destination: Hashable, Sendable {
        case tab(AppTab)
        case allActivity
    }

    let id: String
    let title: String
    let systemImage: String
    let destination: Destination

    static let defaults: [QuickAction] = [
        QuickAction(id: "activity", title: String(localized: "Activity"), systemImage: "list.bullet.rectangle", destination: .allActivity),
        QuickAction(id: "analytics", title: String(localized: "Analytics"), systemImage: "chart.xyaxis.line", destination: .tab(.analytics)),
        QuickAction(id: "notifications", title: String(localized: "Alerts"), systemImage: "bell", destination: .tab(.notifications)),
        QuickAction(id: "profile", title: String(localized: "Account"), systemImage: "person.crop.circle", destination: .tab(.profile)),
    ]
}
