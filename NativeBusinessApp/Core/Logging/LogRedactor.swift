import Foundation

/// Produces log-safe descriptions of requests. Credentials, tokens and other secrets are replaced
/// with a placeholder before anything is written to a log.
enum LogRedactor {
    static let placeholder = "<redacted>"

    /// Header names whose values are always redacted (compared case-insensitively).
    static let sensitiveHeaders: Set<String> = [
        "authorization", "proxy-authorization", "cookie", "set-cookie", "x-api-key", "x-auth-token",
    ]

    /// JSON keys whose values are always redacted. Keys are normalised (lowercased, `_`/`-` removed),
    /// so `refresh_token`, `refreshToken` and `Refresh-Token` all match `refreshtoken`.
    static let sensitiveKeys: Set<String> = [
        "password", "newpassword", "currentpassword", "token", "accesstoken", "refreshtoken", "idtoken",
        "secret", "clientsecret", "apikey", "otp", "authorization", "code",
    ]

    static func isSensitiveKey(_ key: String) -> Bool {
        let normalised = key.lowercased().filter { $0 != "_" && $0 != "-" }
        return sensitiveKeys.contains(normalised)
    }

    static func redact(headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, header in
            result[header.key] = sensitiveHeaders.contains(header.key.lowercased()) ? placeholder : header.value
        }
    }

    /// Returns a redacted JSON string, or a size summary for non-JSON payloads.
    static func redact(body: Data?) -> String {
        guard let body, !body.isEmpty else { return "<empty>" }
        guard let object = try? JSONSerialization.jsonObject(with: body, options: [.fragmentsAllowed]) else {
            return "<\(body.count) bytes, non-JSON>"
        }
        let redacted = redact(jsonObject: object)
        guard
            let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys, .fragmentsAllowed]),
            let string = String(data: data, encoding: .utf8)
        else {
            return "<\(body.count) bytes>"
        }
        return string
    }

    /// Removes user info and redacts sensitive query parameter values.
    static func redact(url: URL?) -> String {
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return "<invalid url>"
        }
        components.user = nil
        components.password = nil
        components.queryItems = components.queryItems?.map { item in
            isSensitiveKey(item.name) ? URLQueryItem(name: item.name, value: placeholder) : item
        }
        return components.string ?? "<invalid url>"
    }

    static func describe(_ request: URLRequest, includeBody: Bool) -> String {
        let method = request.httpMethod ?? "GET"
        let headers = redact(headers: request.allHTTPHeaderFields ?? [:])
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        var description = "\(method) \(redact(url: request.url)) [\(headers)]"
        if includeBody {
            description += " body=\(redact(body: request.httpBody))"
        }
        return description
    }

    private static func redact(jsonObject: Any) -> Any {
        if let dictionary = jsonObject as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, element in
                result[element.key] = isSensitiveKey(element.key) ? placeholder : redact(jsonObject: element.value)
            }
        }
        if let array = jsonObject as? [Any] {
            return array.map(redact(jsonObject:))
        }
        return jsonObject
    }
}
