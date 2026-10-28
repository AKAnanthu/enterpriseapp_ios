# API Integration

> **Status: illustrative contract.** Every path, field name and response shape below is an
> **assumption** made so the client could be built before the backend was specified. None of it has
> been verified against a real server. Replace or confirm each item using the checklist at the end.

## API client design

```
Repository ──► APIClient (protocol)
                 └─ AuthenticatedAPIClient ── token + single refresh/retry on 401
                      └─ HTTPClient ── RequestBuilder → HTTPTransport → ResponseValidator → RetryPolicy → JSON decode
                           └─ HTTPTransport (protocol): URLSession | MockBackendTransport (DEBUG) | test stubs
```

| Type | File | Responsibility |
| --- | --- | --- |
| `HTTPMethod` | `Core/Networking/HTTPMethod.swift` | GET/POST/PUT/PATCH/DELETE and idempotency |
| `APIEndpoint<Response>` | `APIEndpoint.swift` | Typed, side-effect-free description of a call (path, query, headers, body, auth, timeout, retry eligibility) |
| `APIPath.make(_:)` | `APIEndpoint.swift` | Percent-encodes dynamic path segments, so an id like `a/b` cannot add segments |
| `APIConfiguration` | `APIConfiguration.swift` | Base URL, timeout, default headers, retry policy, `URLSessionConfiguration.api(timeout:)` |
| `RequestBuilder` | `RequestBuilder.swift` | Joins paths safely (rejects `..`, `//` and absolute URLs), sets headers, encodes JSON, adds `Authorization: Bearer` |
| `HTTPClient` | `HTTPClient.swift` | Sends, validates status, retries, decodes. It never reads tokens itself. |
| `AuthenticatedAPIClient` | `APIClient.swift` | Attaches the access token, refreshes once on `401`, and ends the session on a second `401` |
| `ResponseValidator` | `ResponseValidator.swift` | Status → `APIError`, parses `Retry-After` (seconds or HTTP-date) |
| `RetryPolicy` | `RetryPolicy.swift` | Bounded exponential backoff for transient failures |
| `APIError` | `APIError.swift` | Every failure category, with no payloads or secrets |
| `JSONCoding` | `JSONCoding.swift` | ISO 8601 dates with or without fractional seconds |
| `LossyArray` | `Core/Utilities/LossyArray.swift` | Skips malformed list elements instead of failing the whole response |
| `NetworkLogger` / `LogRedactor` | `Core/Logging` | Redacted diagnostics |

### URLSession configuration

`URLSessionConfiguration.api(timeout:)` uses an **ephemeral** session: no disk URL cache, cookie
store or credential persistence, so authenticated responses are never written to disk.
`waitsForConnectivity = false` makes offline failures surface immediately. Request timeout comes from
`API_TIMEOUT_SECONDS`, and the resource timeout is twice that. TLS and certificate validation use
the system defaults (App Transport Security). The app never overrides server trust.

### Retry policy

- Only endpoints with `allowsAutomaticRetry` are retried. By default that means idempotent methods
  (GET, PUT, DELETE). **POST and PATCH are never retried automatically.**
- Retried failures: timeouts, `502`, `503`, `504`, and `429` whose `Retry-After` is ≤ 8 s.
- At most 2 retries with exponential backoff (0.5 s, 1 s). `Retry-After` is honoured when present.
- Not retried: offline, `4xx` (other than 429), `500`, decoding errors, cancellations.
- Cancelling the calling task cancels the in-flight request and any pending backoff.

### Authentication handling

- `requiresAuthentication: true` (the default) adds `Authorization: Bearer <accessToken>`.
- On `401`: `TokenRefreshService.refreshAccessToken(rejectedToken:)` runs once (concurrent `401`s
  share one refresh), then the request is retried exactly once. A second `401` invalidates the
  session. Replaying a POST after a `401` is safe because the server rejected it before processing.
- Auth endpoints (`login`, `refresh`, `logout`) are `requiresAuthentication: false`. The refresh call
  goes through `HTTPClient` directly, so it can never trigger another refresh.

## Configuration

Set the base URL per environment in `Config/{Development,Staging,Production}.xcconfig`, or locally in
the git-ignored `Config/Local.xcconfig`:

```
API_BASE_URL = https:/$()/api.yourcompany.com/v1     // `$()` keeps "//" from starting a comment
API_TIMEOUT_SECONDS = 30
LOGIN_IDENTIFIER_KIND = email                        // or: username
PASSWORD_RESET_URL = https:/$()/yourcompany.com/reset
```

Equivalent example environment values (for reference only; the app does **not** read `.env` files):

```
API_BASE_URL=https://api.example.com
API_TIMEOUT_SECONDS=30
```

Validation in `AppConfiguration.load(from:)`:

- The URL must be absolute with a host and no query.
- The scheme must be `https`. `http` is allowed **only** for `localhost`/`127.0.0.1` in development.
- Reserved example domains (`example.com/.org/.net`, `.test`, `.invalid`, `.example`) are rejected in
  staging and production. The app shows a configuration screen instead of starting. In development
  they are allowed, and DEBUG builds show a warning banner on the login screen.

Endpoint paths are relative to the base URL, so `https://host/v1` + `auth/login` → `https://host/v1/auth/login`.

## Endpoint contracts (illustrative)

Dates are ISO 8601 strings (`2026-01-01T09:30:00Z`, fractional seconds allowed). Unknown JSON
fields are ignored.

### Login: `POST /auth/login` (no auth)

```json
{ "email": "user@example.com", "password": "example-password" }
```
With `LOGIN_IDENTIFIER_KIND = username`, the key is `"username"` instead of `"email"`.

`200` response:
```json
{
  "accessToken": "example-access-token",
  "refreshToken": "example-refresh-token",
  "expiresIn": 900,
  "tokenType": "Bearer",
  "user": { "id": "user-123", "name": "Example User", "email": "user@example.com" }
}
```
- Required: a non-empty `accessToken`. If `tokenType` is present, it must be `Bearer` (case-insensitive).
- Optional: `refreshToken` (without it the session ends at expiry), `expiresIn` in seconds,
  and `user` (without it the app calls `GET /auth/me`).
- `401`, `400` or `422` → "incorrect email or password". `403` → "access denied".

### Token refresh: `POST /auth/refresh` (no auth)

```json
{ "refreshToken": "example-refresh-token" }
```
`200` response: the same token fields as login (no `user`). If the server does not return a new
`refreshToken`, the existing one is kept. `401`, `403`, `400` or `422` are treated as permanent and
sign the user out. Network errors and `5xx` keep the session.

### Current user: `GET /auth/me`

```json
{ "id": "user-123", "name": "Example User", "email": "user@example.com" }
```
Used at launch to validate a restored session. `name` falls back to `email`, then "Account".

### Logout: `POST /auth/logout` (no auth, best effort, 5 s timeout)

```json
{ "refreshToken": "example-refresh-token" }
```
Any response is accepted. Local credentials are cleared first regardless. Set
`RemoteAuthRepository.supportsRemoteLogout = false` if the backend has no such endpoint.

### Dashboard summary: `GET /dashboard/summary`

```json
{
  "metrics": [
    { "id": "transactions", "title": "Total transactions", "value": 1284, "format": "count", "changePercent": 6.4 },
    { "id": "revenue", "title": "Monthly revenue", "value": 48250.75, "format": "currency", "currencyCode": "USD", "changePercent": 3.1 },
    { "id": "completion", "title": "Completion rate", "value": 0.942, "format": "percentage" }
  ],
  "generatedAt": "2026-01-01T09:30:00Z"
}
```
`format`: `count`, `number` (default), `currency` (needs a 3-letter `currencyCode`) or
`percentage` (a fraction). `changePercent` is a percentage, e.g. `6.4` = +6.4%. Duplicate ids are dropped.

### Recent activity: `GET /dashboard/activity?limit=5`

```json
{
  "items": [
    { "id": "act-1001", "title": "Invoice #1001 settled", "description": "Billing", "category": "Billing",
      "occurredAt": "2026-01-01T09:00:00Z", "status": "completed", "amount": 1250, "currencyCode": "USD" }
  ]
}
```
`status` maps `completed/success/done`, `pending/processing/in_progress` and
`failed/error/rejected/cancelled`; any other value is shown verbatim. Items are de-duplicated and
sorted newest first. **No pagination is assumed.** The "See All" screen requests `limit=50`.

### Analytics: `GET /analytics/overview?range=7d|30d|90d`

```json
{
  "metrics": [ { "id": "avg-order", "title": "Average order value", "value": 182.4, "format": "currency", "currencyCode": "USD" } ],
  "series": [
    { "id": "revenue", "title": "Daily revenue", "chartType": "line",
      "points": [ { "date": "2026-01-01T00:00:00Z", "value": 1400 } ] }
  ]
}
```
`chartType`: `line` (default) or `bar`. Points are sorted by date. Non-finite values are dropped.

### Notifications

- `GET /notifications` →
  `{ "items": [ { "id": "n1", "title": "…", "message": "…", "createdAt": "…", "isRead": false, "category": "Approvals" } ] }`
- `PATCH /notifications/{id}` with body `{ "isRead": true }` → any `2xx`
- `POST /notifications/read-all` → any `2xx`

### Profile: `GET /profile`

```json
{ "id": "user-123", "name": "Example User", "email": "user@example.com", "role": "Operations Manager",
  "organization": "Example Organization", "phone": "+1 555 0100", "memberSince": "2025-01-01T00:00:00Z",
  "avatarURL": "https://cdn.example.com/avatar.png" }
```
`avatarURL` is loaded only over HTTPS and without credentials.

## Error mapping

| Condition | `APIError` | User-facing (`UserFacingError.kind`) | Retry button |
| --- | --- | --- | --- |
| No internet / connection lost | `noConnection` | offline: "You're offline" | yes |
| DNS / host unreachable | `cannotReachServer` | serverUnreachable | yes |
| URLError timeout, HTTP 408 | `timeout` | timeout | yes |
| Task / request cancelled | `cancelled` | not presented | n/a |
| 401 | `unauthorized` | sessionExpired (or invalid credentials at login) | no |
| 403 | `forbidden` | accessDenied | no |
| 404 | `notFound` | notFound | no |
| 400, 422 | `validationFailed` | validation | no |
| 429 | `rateLimited(retryAfter:)` | rateLimited | yes |
| 5xx | `server(statusCode:)` | server: "Something went wrong" | yes |
| Other status | `unexpectedStatus` | server | yes |
| Missing body / bad JSON | `emptyResponse` / `decodingFailed(type)` | server | yes |
| Keychain failure | `keychain(KeychainError)` | storage | yes |
| Bad base URL / path | `invalidConfiguration` / `invalidURL` / `invalidRequest` | configuration | no |
| Other transport error (e.g. TLS) | `transport(code:)` | server | yes |

User-facing messages never include status codes, type names, server messages or payloads.

## Backend integration checklist

- [ ] Set real `API_BASE_URL` values for development, staging and production.
- [ ] Confirm the login identifier (`email` vs `username`) and update `LOGIN_IDENTIFIER_KIND`.
- [ ] Confirm the auth paths in `Features/Authentication/Data/AuthEndpoints.swift`.
- [ ] Align `LoginResponseDTO` / `TokenResponseDTO` / `UserDTO` field names (e.g. `access_token`):
      change the DTOs or add `CodingKeys`. The domain and UI do not change.
- [ ] Confirm what status code bad credentials return and how lockout is signalled (adjust `RemoteAuthRepository.login`).
- [ ] Confirm token lifetime semantics (`expiresIn`), refresh-token rotation, and the refresh failure
      statuses (adjust `TokenRefreshService.isPermanentRefreshFailure`).
- [ ] Confirm whether `POST /auth/logout` exists (`supportsRemoteLogout`).
- [ ] Map the dashboard, activity, analytics, notifications and profile payloads in each feature's `Data` folder.
- [ ] Decide on pagination for activity and notifications if lists can be large.
- [ ] Add any required headers (API version, locale) via `APIConfiguration.defaultHeaders`. Never add secrets.
- [ ] If the backend needs custom TLS (e.g. certificate pinning), design it explicitly with your security team.
- [ ] Run the app against staging and update the tests' fixtures to real sample payloads.

## Known contract assumptions

1. JSON over HTTPS. Bearer access tokens in the `Authorization` header.
2. Tokens are opaque. The client never decodes JWT claims.
3. `expiresIn` is relative seconds from receipt. Clock skew is mitigated by a 30 s refresh leeway.
4. A `401` on a normal endpoint means "access token invalid or expired".
5. Refresh is a JSON POST with the refresh token in the body, not a cookie.
6. List endpoints wrap arrays in `{ "items": [...] }`. Metrics use `{ "metrics": [...] }`.
7. Server error bodies are not parsed or shown to users.
8. All demo data in `MockBackendTransport` is fabricated for DEBUG demo/UI-test use and does not
   describe any real system.
