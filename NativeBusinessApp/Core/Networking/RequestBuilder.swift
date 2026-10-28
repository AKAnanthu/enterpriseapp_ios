import Foundation

/// Converts an `APIEndpoint` into a `URLRequest`. Pure and synchronous, so it is trivially testable.
struct RequestBuilder: Sendable {
    let configuration: APIConfiguration

    private static let allowedPathCharacters: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.insert("%")
        return set
    }()

    func makeRequest<Response>(for endpoint: APIEndpoint<Response>, accessToken: String?) throws(APIError) -> URLRequest {
        let url = try makeURL(path: endpoint.path, queryItems: endpoint.queryItems)

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout ?? configuration.requestTimeout
        request.cachePolicy = .reloadIgnoringLocalCacheData

        for (field, value) in configuration.defaultHeaders {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        for (field, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        if let body = endpoint.body {
            do {
                request.httpBody = try JSONCoding.makeEncoder().encode(body)
            } catch {
                throw .invalidRequest
            }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws(APIError) -> URL {
        let relativePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let segments = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard
            !relativePath.contains("://"),
            !segments.contains(where: { $0 == ".." || $0 == "." || $0.isEmpty && !relativePath.isEmpty }),
            relativePath.unicodeScalars.allSatisfy(Self.allowedPathCharacters.contains)
        else {
            throw .invalidURL
        }

        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw .invalidConfiguration("Base URL cannot be parsed.")
        }
        var basePath = components.percentEncodedPath
        if basePath.hasSuffix("/") { basePath.removeLast() }
        components.percentEncodedPath = relativePath.isEmpty ? basePath : "\(basePath)/\(relativePath)"
        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }
        guard let url = components.url else { throw .invalidURL }
        return url
    }
}
