# Authentication

Key types: `AuthManager` (observable state, `@MainActor`), `TokenRefreshService` (`actor`; token
storage and refresh coordination), `KeychainTokenStore`, `AuthenticatedAPIClient`,
`RemoteAuthRepository`, `RemoteTokenRefresher` and `LoginViewModel`.

## Login flow

1. **Local validation** (`LoginFormValidator`): both fields are required. The email format is checked
   only when `LOGIN_IDENTIFIER_KIND = email`, and leading/trailing whitespace is trimmed from the
   identifier. **The password is never trimmed, transformed, length-checked or persisted.**
   Complexity rules belong to the backend.
2. **Duplicate protection**: `LoginViewModel.isSubmitting` guards re-entry, the form is disabled and
   the button shows progress. `AuthManager.login` also ignores calls while authenticating.
3. **Request**: `RemoteAuthRepository.login` → `POST /auth/login` (unauthenticated endpoint).
4. **Response validation** (`AuthMapper.tokens`): a non-empty access token is required, and if a
   token type is present it must be `Bearer`. Otherwise → `AuthError.invalidTokenResponse`.
5. **Persist**: `TokenRefreshService.save` writes the bundle to the Keychain. A Keychain failure
   aborts the login with an error.
6. **User**: taken from the login response, or fetched with `GET /auth/me`.
7. **State**: `AuthManager.state = .authenticated(user)`. `AppCoordinator.route` becomes `.main(user)`
   and the tab shell appears. The view model never navigates, so the dashboard cannot appear
   before step 5 succeeds.
8. **Errors**: `401/400/422` → "The email (or username) or password is incorrect.", `403` → access denied,
   offline/timeout/server → a generic message. Errors are announced to VoiceOver. On success the
   password is cleared from the view model.

Nothing about credentials is logged: the network logger records method and path only, and
verbose DEBUG logging redacts `password`, tokens and the `Authorization` header.

## JWT handling

- Access and refresh tokens are **opaque strings**. The app does not decode JWTs, read claims or
  verify signatures, because client-side decoding proves nothing about authenticity. The backend
  remains the only authority on authorization.
- Expiry comes from the response's `expiresIn` (seconds) at receipt. `TokenRefreshService` refreshes
  **proactively** when the stored expiry is within 30 s, and **reactively** when any request returns `401`.
- Unknown expiry (no `expiresIn`) is treated as valid until the server says otherwise.
- `AuthTokens.description` is redacted, so tokens cannot leak through interpolation or `print`.

## Keychain storage

`KeychainTokenStore` stores **one generic-password item** (`service = <bundle id>.auth`,
`account = auth-session`) containing the JSON-encoded `AuthTokens` (access token, refresh token,
expiry, type).

- **Atomic updates**: both tokens live in a single item, updated with one `SecItemUpdate` (or
  `SecItemAdd` the first time). The stored access and refresh tokens can never come from different sessions.
- **Accessibility**: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
  - *Why*: tokens stay readable after the first unlock following a reboot, so a refresh can finish if
    the app resumes in the background. `ThisDeviceOnly` keeps the item out of iCloud Keychain and
    out of backups restored to other devices.
  - *Trade-off*: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is stricter (unreadable while locked).
    Prefer it if the app never runs network work in the background.
- **Isolation**: no shared access group, so other apps cannot read the item. `kSecAttrSynchronizable = false`.
- **Never stored elsewhere**: no tokens in `UserDefaults`, files, source code or logs. The only
  `UserDefaults` value is a boolean first-launch marker (see below).
- **Reinstall**: Keychain items survive app deletion. `FreshInstallGuard` clears stale tokens on the
  first launch after install, so a reinstall does not silently restore the previous session.
- **Errors**: `KeychainError.unexpectedStatus(OSStatus)`, `.invalidItemData` and `.encodingFailed`
  map to `APIError.keychain` and the "Secure storage unavailable" message.

## Token refresh behaviour

`TokenRefreshService` (actor):

| Situation | Behaviour |
| --- | --- |
| Many requests get `401` at once | One refresh `Task`; every caller awaits it (coalesced) |
| A caller's rejected token was already replaced | Returns the current token; no new refresh |
| Refresh succeeds | Both tokens saved atomically; `.refreshSucceeded` event; requests retried once |
| No new refresh token in response | The existing refresh token is kept (rotation not assumed) |
| Refresh returns `401/403/400/422`, or no refresh token exists | **Permanent**: tokens cleared, `.sessionExpired` event, user sent to login with "Your session expired" |
| Refresh fails offline / timeout / `5xx` | **Transient**: tokens kept; the error goes to the screen with a retry |
| Retried request gets `401` again | Session invalidated (no loop) |
| Logout or new login during a refresh | Generation counter discards the late result; it is never saved |

Infinite loops are impossible by construction: the refresh endpoint is unauthenticated and called
through `HTTPClient` (not `AuthenticatedAPIClient`), and each request gets at most one refresh-and-retry.

## Session restoration

On launch (`AppCoordinator.start()` → `AuthManager.restoreSession()`, asynchronously after the first frame):

1. Read the Keychain item.
   - None → **login**.
   - Corrupt (`invalidItemData`) → item deleted → **login**.
   - Other Keychain error (e.g. `errSecInteractionNotAllowed`) → **restoration failed** screen
     (Try Again / Sign Out); tokens are kept.
2. Validate with the server: `GET /auth/me` through the authenticated client (proactive or reactive
   refresh applies). **Token presence alone never signs the user in.**
   - Success → **authenticated**.
   - Rejected / permanent refresh failure → tokens cleared → **login** with the "session expired" notice.
   - Offline / timeout / `5xx` → **restoration failed** screen; tokens kept for the retry.

A `LaunchView` shows while this runs, and the main thread is never blocked.

## Logout behaviour

`AuthManager.logout()` (Profile → Sign Out → confirmation dialog):

1. Bumps the session generation (in-flight work from this session is ignored from now on).
2. Clears tokens from memory and the Keychain.
3. Sets `.unauthenticated`. The tab shell, its router and all view models are discarded.
4. Calls `POST /auth/logout` with the refresh token **best effort** (5 s timeout, errors ignored).

## Session expiry while signed in

If a refresh fails permanently, `TokenRefreshService` emits `.sessionExpired`. `AuthManager` moves to
`.sessionExpired`, the coordinator routes to the login screen, and a banner says
"Your session expired. Please sign in again." Events that arrive after logout are ignored.

## Security limitations and assumptions

- Client checks are conveniences. **Authorization is enforced by the server only.**
- Token revocation, rotation, lifetime and lockout policies are backend concerns and are assumed, not
  verified (see API_INTEGRATION.md).
- Anything in the app bundle (base URLs, config) is public. **Never** add client secrets or private
  keys. If the backend requires a confidential client, use a backend-for-frontend instead.
- No certificate pinning is implemented. Standard ATS/TLS validation applies and is never weakened.
- If the Keychain cannot delete the item during logout (very rare), memory is still cleared and the
  UI signs out, but the item could be restored on the next launch. The failure is logged.
- No biometric unlock, MFA or password reset flow is implemented (out of scope).
- DEBUG-only demo mode uses an in-memory store and fake tokens. It is compiled out of Staging and Release.
