import SwiftUI

/// Consistent confirmation for destructive or significant actions, built on the native
/// `confirmationDialog` so it adapts to iPhone (action sheet) and iPad (popover).
struct ConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    var role: ButtonRole = .destructive
    var confirmIdentifier: String
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
            Button(confirmTitle, role: role, action: onConfirm)
                .accessibilityIdentifier(confirmIdentifier)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

extension View {
    func appConfirmationDialog(
        isPresented: Binding<Bool>,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        confirmTitle: LocalizedStringKey,
        role: ButtonRole = .destructive,
        confirmIdentifier: String = "dialog.confirm",
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(ConfirmationDialogModifier(
            isPresented: isPresented, title: title, message: message, confirmTitle: confirmTitle,
            role: role, confirmIdentifier: confirmIdentifier, onConfirm: onConfirm
        ))
    }
}
