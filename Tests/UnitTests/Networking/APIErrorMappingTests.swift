import Foundation
import Testing
@testable import NativeBusinessApp

@Suite("API error mapping")
struct APIErrorMappingTests {
    @Test(arguments: [
        (400, APIError.validationFailed), (401, .unauthorized), (403, .forbidden), (404, .notFound),
        (408, .timeout), (422, .validationFailed), (429, .rateLimited(retryAfter: nil)),
        (500, .server(statusCode: 500)), (503, .server(statusCode: 503)), (302, .unexpectedStatus(302)), (418, .unexpectedStatus(418)),
    ])
    func mapsStatusCodes(status: Int, expected: APIError) {
        #expect(APIError.from(statusCode: status) == expected)
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, APIError.noConnection), (.networkConnectionLost, .noConnection),
        (.timedOut, .timeout), (.cancelled, .cancelled), (.cannotFindHost, .cannotReachServer),
        (.cannotConnectToHost, .cannotReachServer), (.badURL, .invalidURL),
        (.serverCertificateUntrusted, .transport(code: URLError.Code.serverCertificateUntrusted.rawValue)),
    ])
    func mapsURLErrors(code: URLError.Code, expected: APIError) {
        #expect(APIError(urlError: URLError(code)) == expected)
    }

    @Test func mapsCancellationAndKeychainErrors() {
        #expect(APIError(CancellationError()) == .cancelled)
        #expect(APIError(KeychainError.invalidItemData) == .keychain(.invalidItemData))
        #expect(APIError(APIError.forbidden) == .forbidden)
    }

    @Test func parsesRetryAfterSeconds() throws {
        let response = HTTPURLResponse(url: TestConfig.baseURL, statusCode: 429, httpVersion: nil, headerFields: ["Retry-After": "7"])!
        #expect(throws: APIError.rateLimited(retryAfter: 7)) {
            try ResponseValidator.validate(response, now: Fixtures.referenceDate)
        }
    }

    @Test func parsesRetryAfterHTTPDate() {
        let interval = ResponseValidator.retryAfterInterval("Thu, 01 Jan 2026 00:00:30 GMT", now: Fixtures.referenceDate)
        #expect(interval == 30)
        #expect(ResponseValidator.retryAfterInterval("garbage", now: Fixtures.referenceDate) == nil)
    }

    @Test func successStatusesPassValidation() throws {
        for status in [200, 201, 204, 299] {
            let response = HTTPURLResponse(url: TestConfig.baseURL, statusCode: status, httpVersion: nil, headerFields: nil)!
            try ResponseValidator.validate(response, now: Fixtures.referenceDate)
        }
    }

    @Test func retryPolicyOnlyRetriesTransientIdempotentFailures() {
        let policy = RetryPolicy(maxRetries: 2, baseDelay: 1, maxDelay: 8)
        #expect(policy.delay(after: .timeout, attempt: 0, isRetryEligible: true) == 1)
        #expect(policy.delay(after: .server(statusCode: 503), attempt: 1, isRetryEligible: true) == 2)
        #expect(policy.delay(after: .server(statusCode: 503), attempt: 2, isRetryEligible: true) == nil)
        #expect(policy.delay(after: .server(statusCode: 500), attempt: 0, isRetryEligible: true) == nil)
        #expect(policy.delay(after: .timeout, attempt: 0, isRetryEligible: false) == nil)
        #expect(policy.delay(after: .unauthorized, attempt: 0, isRetryEligible: true) == nil)
        #expect(policy.delay(after: .rateLimited(retryAfter: 3), attempt: 0, isRetryEligible: true) == 3)
        #expect(policy.delay(after: .rateLimited(retryAfter: 60), attempt: 0, isRetryEligible: true) == nil)
    }
}
