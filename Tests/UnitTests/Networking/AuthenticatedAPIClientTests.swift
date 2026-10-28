import Foundation
import Testing
@testable import NativeBusinessApp

@Suite("AuthenticatedAPIClient and refresh coordination")
struct AuthenticatedAPIClientTests {
    private let endpoint = APIEndpoint<SampleResponse>(path: "sample")
    private let okJSON = #"{"id":"ok","value":1}"#

    private func makeClient(
        transport: StubTransport,
        tokens: AuthTokens? = Fixtures.tokens,
        refresher: MockTokenRefresher = MockTokenRefresher()
    ) -> (AuthenticatedAPIClient, TokenRefreshService, InMemoryTokenStore) {
        let store = InMemoryTokenStore(tokens: tokens)
        let service = TokenRefreshService(store: store, refresher: refresher)
        let client = AuthenticatedAPIClient(httpClient: TestConfig.httpClient(transport: transport), tokenProvider: service)
        return (client, service, store)
    }

    @Test func attachesBearerToken() async throws {
        let transport = StubTransport { [okJSON] request, _ in HTTPStub.response(for: request, json: okJSON) }
        let (client, _, _) = makeClient(transport: transport)
        _ = try await client.send(endpoint)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer access-1")
    }

    @Test func unauthenticatedEndpointsCarryNoToken() async throws {
        let transport = StubTransport { [okJSON] request, _ in HTTPStub.response(for: request, json: okJSON) }
        let (client, _, _) = makeClient(transport: transport)
        _ = try await client.send(APIEndpoint<SampleResponse>(path: "public", requiresAuthentication: false))
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func missingSessionFailsWithoutNetworkCall() async {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request) }
        let (client, _, _) = makeClient(transport: transport, tokens: nil)
        await #expect(throws: AuthError.notAuthenticated) { try await client.send(endpoint) }
        #expect(transport.callCount == 0)
    }

    @Test func refreshesOnceAndRetriesAfterUnauthorized() async throws {
        let transport = StubTransport { [okJSON] request, _ in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer access-2"
                ? HTTPStub.response(for: request, json: okJSON)
                : HTTPStub.response(for: request, status: 401)
        }
        let refresher = MockTokenRefresher()
        let (client, service, store) = makeClient(transport: transport, refresher: refresher)

        let result = try await client.send(endpoint)

        #expect(result.id == "ok")
        #expect(refresher.calls == ["refresh-1"])
        #expect(transport.callCount == 2)
        #expect(try store.load() == Fixtures.refreshedTokens)
        #expect(try await service.currentTokens()?.accessToken == "access-2")
    }

    @Test func secondUnauthorizedEndsSessionWithoutLooping() async throws {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 401) }
        let refresher = MockTokenRefresher()
        let (client, service, store) = makeClient(transport: transport, refresher: refresher)
        var events = service.events.makeAsyncIterator()

        await #expect(throws: APIError.unauthorized) { try await client.send(endpoint) }

        #expect(transport.callCount == 2)
        #expect(refresher.calls.count == 1)
        #expect(try store.load() == nil)
        #expect(await events.next() == .refreshStarted)
        #expect(await events.next() == .refreshSucceeded)
        #expect(await events.next() == .sessionExpired)
    }

    @Test func concurrentUnauthorizedRequestsShareOneRefresh() async throws {
        let transport = StubTransport { [okJSON] request, _ in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer access-2"
                ? HTTPStub.response(for: request, json: okJSON)
                : HTTPStub.response(for: request, status: 401)
        }
        let refresher = MockTokenRefresher(delay: .milliseconds(100))
        let (client, _, _) = makeClient(transport: transport, refresher: refresher)

        try await withThrowingTaskGroup(of: SampleResponse.self) { group in
            for _ in 0..<5 {
                group.addTask { try await client.send(endpoint) }
            }
            for try await response in group {
                #expect(response.id == "ok")
            }
        }
        #expect(refresher.calls.count == 1)
    }

    @Test func refreshFailurePropagatesAndClearsSession() async throws {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 401) }
        let refresher = MockTokenRefresher(result: .failure(APIError.unauthorized))
        let (client, _, store) = makeClient(transport: transport, refresher: refresher)

        await #expect(throws: AuthError.sessionExpired) { try await client.send(endpoint) }
        #expect(transport.callCount == 1)
        #expect(try store.load() == nil)
    }

    @Test func refreshEndpointIsNeverAuthenticated() {
        let endpoint = AuthEndpoints.refresh(RefreshRequestDTO(refreshToken: "r"))
        #expect(!endpoint.requiresAuthentication)
        #expect(!endpoint.allowsAutomaticRetry)
    }
}
