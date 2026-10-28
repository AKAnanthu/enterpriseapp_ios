import Foundation

/// Performs a single endpoint call: request building, transport, status validation, bounded retry
/// and decoding. It knows nothing about token storage; callers pass the access token explicitly.
///
/// `AuthenticatedAPIClient` wraps this type for feature code. The token refresh service uses
/// `HTTPClient` directly so a refresh call can never trigger another refresh.
final class HTTPClient: Sendable {
    typealias Sleeper = @Sendable (TimeInterval) async throws -> Void

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let requestBuilder: RequestBuilder
    private let logger: NetworkLogger
    private let now: @Sendable () -> Date
    private let sleep: Sleeper

    init(
        configuration: APIConfiguration,
        transport: any HTTPTransport,
        logger: NetworkLogger = NetworkLogger(),
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping Sleeper = { seconds in try await Task.sleep(for: .seconds(seconds)) }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.requestBuilder = RequestBuilder(configuration: configuration)
        self.logger = logger
        self.now = now
        self.sleep = sleep
    }

    func send<Response>(_ endpoint: APIEndpoint<Response>, accessToken: String?) async throws(APIError) -> Response {
        let request = try requestBuilder.makeRequest(for: endpoint, accessToken: accessToken)
        var attempt = 0
        while true {
            do {
                return try await perform(request, as: Response.self)
            } catch {
                guard let delay = configuration.retryPolicy.delay(
                    after: error, attempt: attempt, isRetryEligible: endpoint.allowsAutomaticRetry
                ) else {
                    throw error
                }
                attempt += 1
                logger.willRetry(request, attempt: attempt, delay: delay, after: error)
                do {
                    try await sleep(delay)
                } catch {
                    throw .cancelled
                }
            }
        }
    }

    private func perform<Response: Decodable>(_ request: URLRequest, as type: Response.Type) async throws(APIError) -> Response {
        if Task.isCancelled { throw .cancelled }
        logger.willSend(request)
        let clock = ContinuousClock()
        let start = clock.now

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch {
            let apiError = APIError(error)
            logger.didFail(request, error: apiError)
            throw apiError
        }
        logger.didReceive(response, for: request, duration: clock.now - start)

        try ResponseValidator.validate(response, now: now())
        return try decode(Response.self, from: data)
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws(APIError) -> Response {
        if let empty = EmptyResponse() as? Response {
            return empty
        }
        guard !data.isEmpty else { throw .emptyResponse }
        do {
            return try JSONCoding.makeDecoder().decode(Response.self, from: data)
        } catch {
            logger.decodingFailed(String(describing: Response.self), error: error)
            throw .decodingFailed(String(describing: Response.self))
        }
    }
}
