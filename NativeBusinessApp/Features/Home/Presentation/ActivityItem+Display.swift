import Foundation

/// Display mapping for `ActivityItem`, keeping the design-system row free of domain types.
extension ActivityItem {
    var statusDisplay: (text: String, style: StatusBadge.Style)? {
        switch status {
        case .completed: (String(localized: "Completed"), .success)
        case .pending: (String(localized: "Pending"), .warning)
        case .failed: (String(localized: "Failed"), .error)
        case .other(let text): (text.capitalized, .neutral)
        case nil: nil
        }
    }

    var systemImage: String {
        switch status {
        case .completed: "checkmark.circle"
        case .pending: "clock"
        case .failed: "exclamationmark.circle"
        case .other, nil: "doc.text"
        }
    }

    var subtitle: String? {
        detail ?? category
    }
}
