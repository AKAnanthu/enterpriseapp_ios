import Foundation
import Synchronization
import Testing
@testable import NativeBusinessApp

@Suite("HTTPClient")
struct HTTPClientTests {
    private let endpoint = APIEndpoint<SampleResponse>(path: "sample", requiresAuthentication: false)

    @Test func decodesSuccessfulResponse() async throws {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, json: #"{"id":"a","value":3}"#) }
        let result = try await TestConfig.httpClient(transport: transport).send(endpoint, accessToken: nil)
        #expect(result == SampleResponse(id: "a", value: 3))
    }

    @Test func mapsUnauthorized() async {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 401) }
        await #expect(throws: APIError.unauthorized) {
            try await TestConfig.httpClient(transport: transport).send(endpoint, accessToken: "t")
        }
    }

    @Test func mapsServerError() async {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 500) }
        await #expect(throws: APIError.server(statusCode: 500)) {
            try await TestConfig.httpClient(transport: transport).send(endpoint, accessToken: nil)
        }
    }

    @Test func malformedJSONIsDecodingFailure() async {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, json: #"{"id": 42"#) }
        await #expect(throws: APIError.decodingFailed("SampleResponse")) {
            try await TestConfig.httpClient(transport: transport).send(endpoint, accessToken: nil)
        }
    }

    @Test func emptyBodyForRequiredPayloadIsEmptyResponse() async {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 200, json: "") }
        await #expect(throws: APIError.emptyResponse) {
            try await TestConfig.httpClient(transport: transport).send(endpoint, accessToken: nil)
        }
    }

    @Test func emptyResponseTypeAcceptsNoContent() async throws {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 204, json: "") }
        let result = try await TestConfig.httpClient(transport: transport)
            .send(APIEndpoint<EmptyResponse>(path: "x", method: .delete), accessToken: nil)
        #expect(result == EmptyResponse())
    }

    @Test func mapsTimeout() async {
        let transport = StubTransport { _, _ in throw URLError(.timedOut) }
        await #expect(throws: APIError.timeout) {
            try await TestConfig.httpClient(transport: transport).send(endpoint, accessToken: nil)
        }
    }

    @Test func mapsOffline() async {
        let transport = StubTransport { _, _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: APIError.noConnection) {
            try await TestConfig.httpClient(transport: transport).send(endpoint, accessToken: nil)
        }
        #expect(transport.callCount == 1) // Offline is not retried.
    }

    @Test func cancellationStopsTheRequest() async {
        let transport = StubTransport { request, _ in
            try await Task.sleep(for: .seconds(10))
            return HTTPStub.response(for: request)
        }
        let client = TestConfig.httpClient(transport: transport)
        let task = Task { try await client.send(endpoint, accessToken: nil) }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        await #expect(throws: APIError.cancelled) { try await task.value }
    }

    @Test func retriesIdempotentRequestAfterTransientFailure() async throws {
        let transport = StubTransport { request, index in
            index < 2 ? HTTPStub.response(for: request, status: 503) : HTTPStub.response(for: request, json: #"{"id":"ok","value":1}"#)
        }
        let delays = Mutex<[TimeInterval]>([])
        let client = HTTPClient(
            configuration: TestConfig.api(retry: RetryPolicy(maxRetries: 2, baseDelay: 0.5, maxDelay: 8)),
            transport: transport,
            sleep: { delay in delays.withLock { $0.append(delay) } }
        )
        let result = try await client.send(endpoint, accessToken: nil)
        #expect(result.id == "ok")
        #expect(transport.callCount == 3)
        #expect(delays.withLock { $0 } == [0.5, 1.0])
    }

    @Test func retriesAreBounded() async {
        let transport = StubTransport { _, _ in throw URLError(.timedOut) }
        let client = TestConfig.httpClient(transport: transport, retry: RetryPolicy(maxRetries: 2, baseDelay: 0, maxDelay: 1))
        await #expect(throws: APIError.timeout) { try await client.send(endpoint, accessToken: nil) }
        #expect(transport.callCount == 3)
    }

    @Test func doesNotRetryNonIdempotentRequests() async {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 503) }
        let client = TestConfig.httpClient(transport: transport, retry: RetryPolicy(maxRetries: 2, baseDelay: 0, maxDelay: 1))
        let post = APIEndpoint<SampleResponse>(path: "orders", method: .post, requiresAuthentication: false)
        await #expect(throws: APIError.server(statusCode: 503)) { try await client.send(post, accessToken: nil) }
        #expect(transport.callCount == 1)
    }

    @Test func respectsRetryAfterForRateLimiting() async throws {
        let transport = StubTransport { request, index in
            index == 0
                ? HTTPStub.response(for: request, status: 429, headers: ["Retry-After": "2"])
                : HTTPStub.response(for: request, json: #"{"id":"ok","value":1}"#)
        }
        let delays = Mutex<[TimeInterval]>([])
        let client = HTTPClient(configuration: TestConfig.api(retry: .standard), transport: transport,
                                sleep: { delay in delays.withLock { $0.append(delay) } })
        _ = try await client.send(endpoint, accessToken: nil)
        #expect(delays.withLock { $0 } == [2])
    }
}
