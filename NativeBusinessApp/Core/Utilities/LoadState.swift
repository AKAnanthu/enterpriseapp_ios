import Foundation

/// Loading lifecycle for a screen or an independently loaded section.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(UserFacingError)

    var value: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var error: UserFacingError? {
        if case .failed(let error) = self { return error }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

extension LoadState: Equatable where Value: Equatable {}
extension LoadState: Sendable where Value: Sendable {}

extension LoadState where Value: Collection {
    /// Maps an empty collection to `.empty`.
    static func from(_ value: Value) -> LoadState {
        value.isEmpty ? .empty : .loaded(value)
    }
}
