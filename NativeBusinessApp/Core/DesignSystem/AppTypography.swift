import SwiftUI

/// Type scale built on system text styles, so every token scales with Dynamic Type.
enum AppTypography {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title2.weight(.semibold)
    static let sectionTitle = Font.headline
    static let body = Font.body
    static let bodyEmphasized = Font.body.weight(.semibold)
    static let subheadline = Font.subheadline
    static let subheadlineEmphasized = Font.subheadline.weight(.medium)
    static let caption = Font.caption
    static let captionEmphasized = Font.caption.weight(.semibold)
    static let button = Font.body.weight(.semibold)
    /// Monospaced digits keep KPI values from jittering when they update.
    static let metricValue = Font.title2.weight(.semibold).monospacedDigit()
    static let amount = Font.subheadline.weight(.semibold).monospacedDigit()
}
