import Foundation

/// The signed-in user as known to the session.
struct User: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String?

    /// Up to two initials for avatar fallbacks, e.g. "Example User" → "EU".
    var initials: String {
        let parts = name.split(whereSeparator: \.isWhitespace).prefix(2)
        let letters = parts.compactMap(\.first).map { String($0).uppercased() }
        return letters.isEmpty ? "?" : letters.joined()
    }

    /// First word of the display name, used in greetings.
    var firstName: String {
        name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? name
    }
}
