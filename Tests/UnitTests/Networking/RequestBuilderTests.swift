import Foundation
import Testing
@testable import NativeBusinessApp

@Suite("RequestBuilder")
struct RequestBuilderTests {
    private let builder = RequestBuilder(configuration: APIConfiguration(
        baseURL: URL(string: "https://api.test.invalid/v1/")!, requestTimeout: 15, defaultHeaders: ["X-Client": "ios"]
    ))

    @Test func joinsBasePathAndEndpointPath() throws {
        let request = try builder.makeRequest(for: APIEndpoint<EmptyResponse>(path: "/dashboard/summary"), accessToken: nil)
        #expect(request.url?.absoluteString == "https://api.test.invalid/v1/dashboard/summary")
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 15)
    }

    @Test func appendsQueryItems() throws {
        let endpoint = APIEndpoint<EmptyResponse>(path: "dashboard/activity", queryItems: [URLQueryItem(name: "limit", value: "5")])
        let request = try builder.makeRequest(for: endpoint, accessToken: nil)
        #expect(request.url?.absoluteString == "https://api.test.invalid/v1/dashboard/activity?limit=5")
    }

    @Test func setsHeadersAndBearerToken() throws {
        let endpoint = APIEndpoint<EmptyResponse>(path: "profile", headers: ["Authorization": "spoofed"])
        let request = try builder.makeRequest(for: endpoint, accessToken: "token-abc")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-abc")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Client") == "ios")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test func omitsAuthorizationWithoutToken() throws {
        let request = try builder.makeRequest(for: APIEndpoint<EmptyResponse>(path: "auth/login", method: .post), accessToken: nil)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func encodesJSONBody() throws {
        let endpoint = APIEndpoint<EmptyResponse>(path: "auth/refresh", method: .post, body: RefreshRequestDTO(refreshToken: "r-1"))
        let request = try builder.makeRequest(for: endpoint, accessToken: nil)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.httpBody)
        #expect(String(decoding: body, as: UTF8.self) == #"{"refreshToken":"r-1"}"#)
    }

    @Test(arguments: [HTTPMethod.get, .post, .put, .patch, .delete])
    func usesEndpointMethod(method: HTTPMethod) throws {
        let request = try builder.makeRequest(for: APIEndpoint<EmptyResponse>(path: "items", method: method), accessToken: nil)
        #expect(request.httpMethod == method.rawValue)
    }

    @Test func endpointTimeoutOverridesDefault() throws {
        let request = try builder.makeRequest(for: APIEndpoint<EmptyResponse>(path: "auth/logout", timeout: 5), accessToken: nil)
        #expect(request.timeoutInterval == 5)
    }

    @Test(arguments: ["https://evil.example/steal", "../admin", "items/../../admin", "items//x", "a b"])
    func rejectsUnsafePaths(path: String) {
        #expect(throws: APIError.invalidURL) {
            try builder.makeRequest(for: APIEndpoint<EmptyResponse>(path: path), accessToken: nil)
        }
    }

    @Test func pathSegmentsAreEncoded() throws {
        let path = NotificationsEndpoints.Path.item("a/b c")
        #expect(path == "notifications/a%2Fb%20c")
        let request = try builder.makeRequest(for: APIEndpoint<EmptyResponse>(path: path), accessToken: nil)
        #expect(request.url?.absoluteString == "https://api.test.invalid/v1/notifications/a%2Fb%20c")
    }

    @Test func retryEligibilityFollowsIdempotency() {
        #expect(APIEndpoint<EmptyResponse>(path: "x", method: .get).allowsAutomaticRetry)
        #expect(APIEndpoint<EmptyResponse>(path: "x", method: .put).allowsAutomaticRetry)
        #expect(!APIEndpoint<EmptyResponse>(path: "x", method: .post).allowsAutomaticRetry)
        #expect(!APIEndpoint<EmptyResponse>(path: "x", method: .patch).allowsAutomaticRetry)
    }
}
