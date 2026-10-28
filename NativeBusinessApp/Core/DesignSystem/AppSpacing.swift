import SwiftUI

/// 4-point spacing scale.
enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum AppRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
}

enum AppLayout {
    /// Apple's recommended minimum hit target.
    static let minTouchTarget: CGFloat = 44
    /// Keeps forms and content readable on iPad and in landscape.
    static let maxReadableWidth: CGFloat = 680
    static let maxFormWidth: CGFloat = 440
}
