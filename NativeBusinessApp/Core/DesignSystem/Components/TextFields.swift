import SwiftUI

/// Labeled text field with inline validation. Focus is driven by the parent's `FocusState`.
struct AppTextField<Field: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var text: String
    /// Plain `Text` so placeholders such as an example address are not parsed as Markdown links.
    var prompt: Text?
    var systemImage: String?
    var error: String?
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .next
    var focus: FocusState<Field?>.Binding
    var field: Field
    var accessibilityIdentifier: String

    var body: some View {
        FieldContainer(title: title, error: error, isFocused: focus.wrappedValue == field, accessibilityIdentifier: accessibilityIdentifier) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityHidden(true)
            }
            TextField(text: $text, prompt: prompt) { Text(title) }
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(submitLabel)
                .focused(focus, equals: field)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityHint(error.map { Text($0) } ?? Text(""))
        }
    }
}

/// Password field with a visibility toggle. The entered value is never trimmed or transformed.
struct SecureTextField<Field: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var text: String
    @Binding var isRevealed: Bool
    var prompt: Text?
    var error: String?
    var contentType: UITextContentType = .password
    var submitLabel: SubmitLabel = .go
    var focus: FocusState<Field?>.Binding
    var field: Field
    var accessibilityIdentifier: String

    var body: some View {
        FieldContainer(title: title, error: error, isFocused: focus.wrappedValue == field, accessibilityIdentifier: accessibilityIdentifier) {
            Image(systemName: "lock")
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityHidden(true)
            Group {
                if isRevealed {
                    TextField(text: $text, prompt: prompt) { Text(title) }
                } else {
                    SecureField(text: $text, prompt: prompt) { Text(title) }
                }
            }
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(submitLabel)
            .focused(focus, equals: field)
            .accessibilityIdentifier(accessibilityIdentifier)
            .accessibilityHint(error.map { Text($0) } ?? Text(""))

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: AppLayout.minTouchTarget, height: AppLayout.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? Text("Hide password") : Text("Show password"))
            .accessibilityIdentifier("\(accessibilityIdentifier).visibilityToggle")
        }
    }
}

/// Shared chrome for text inputs: label, rounded field, focus/error border and error message.
private struct FieldContainer<Content: View>: View {
    let title: LocalizedStringKey
    let error: String?
    let isFocused: Bool
    let accessibilityIdentifier: String
    @ViewBuilder let content: Content

    private var borderColor: Color {
        if error != nil { return AppColors.error }
        return isFocused ? AppColors.actionText : AppColors.separator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.subheadlineEmphasized)
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityHidden(true)

            HStack(spacing: AppSpacing.sm) {
                content
            }
            .font(AppTypography.body)
            .foregroundStyle(AppColors.textPrimary)
            .padding(.leading, AppSpacing.md)
            .frame(minHeight: AppLayout.minTouchTarget + 8)
            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused || error != nil ? 1.5 : 0.5)
            )

            if let error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.error)
                    .accessibilityIdentifier("\(accessibilityIdentifier).error")
            }
        }
    }
}
