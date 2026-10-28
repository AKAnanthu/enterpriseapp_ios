import Foundation

/// Decodes an array while skipping elements that fail to decode, so one malformed item from the
/// server does not blank an entire section. The number of dropped elements is exposed for logging.
struct LossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
    let elements: [Element]
    let droppedCount: Int

    init(_ elements: [Element]) {
        self.elements = elements
        self.droppedCount = 0
    }

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        var dropped = 0
        while !container.isAtEnd {
            do {
                elements.append(try container.decode(Element.self))
            } catch {
                dropped += 1
                // A failed decode does not advance the container; consume the element explicitly.
                guard (try? container.decode(DiscardedElement.self)) != nil else { break }
            }
        }
        self.elements = elements
        self.droppedCount = dropped
        if dropped > 0 {
            AppLogger.network.notice("Dropped \(dropped, privacy: .public) malformed \(String(describing: Element.self), privacy: .public) element(s)")
        }
    }

    private struct DiscardedElement: Decodable {}
}
