import Foundation

/// The lowest-level seam of the networking stack: sends a request and returns raw bytes.
///
/// `URLSession` is the production implementation. Tests inject a stub transport or a
/// `URLSession` configured with a `URLProtocol` stub; the DEBUG-only demo backend is another
/// implementation, so the rest of the stack (request building, validation, decoding, auth)
/// is exercised identically in every mode.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

extension URLSession: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (data, httpResponse)
    }
}
