import SwiftUI

/// Filled, full-width primary call to action with an optional loading state.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading = false
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                ButtonLabel(title: title, systemImage: systemImage)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(AppColors.onAction)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(FilledButtonStyle(isLoading: isLoading))
        .allowsHitTesting(!isLoading)
        .accessibilityValue(isLoading ? Text("In progress") : Text(""))
    }
}

/// Outlined secondary action.
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var role: ButtonRole?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            ButtonLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(OutlinedButtonStyle(isDestructive: role == .destructive))
    }
}

private struct ButtonLabel: View {
    let title: LocalizedStringKey
    let systemImage: String?

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(AppTypography.button)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: AppLayout.minTouchTarget + 6)
        .padding(.horizontal, AppSpacing.lg)
        .contentShape(Capsule())
    }
}

struct FilledButtonStyle: ButtonStyle {
    var isLoading = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppColors.onAction)
            .background(AppColors.actionFill, in: Capsule())
            .opacity(isEnabled || isLoading ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OutlinedButtonStyle: ButtonStyle {
    var isDestructive = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let tint = isDestructive ? AppColors.error : AppColors.actionText
        configuration.label
            .foregroundStyle(tint)
            .background(AppColors.surfaceCard, in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.5), lineWidth: 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
    }
}

#Preview("Buttons") {
    VStack(spacing: AppSpacing.md) {
        PrimaryButton("Sign In") {}
        PrimaryButton("Sign In", isLoading: true) {}
        PrimaryButton("Disabled") {}.disabled(true)
        SecondaryButton("Try Again", systemImage: "arrow.clockwise") {}
        SecondaryButton("Sign Out", role: .destructive) {}
    }
    .padding()
    .appScreenBackground()
}
