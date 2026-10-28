import Foundation
import Testing
@testable import NativeBusinessApp

@Suite("Login form validation")
struct LoginFormValidatorTests {
    private let email = LoginFormValidator(identifierKind: .email)
    private let username = LoginFormValidator(identifierKind: .username)

    @Test func requiresBothFields() {
        let result = email.validate(identifier: "   ", password: "")
        #expect(result.identifierError == .identifierRequired(.email))
        #expect(result.passwordError == .passwordRequired)
        #expect(!result.isValid)
    }

    @Test(arguments: ["user@example.com", "first.last+tag@sub.example.co.uk"])
    func acceptsPlausibleEmails(value: String) {
        #expect(email.validate(identifier: value, password: "x").isValid)
    }

    @Test(arguments: ["user", "user@", "@example.com", "user@example", "user@@example.com", "us er@example.com", "user@example..com"])
    func rejectsInvalidEmails(value: String) {
        #expect(email.validate(identifier: value, password: "x").identifierError == .invalidEmail)
    }

    @Test func trimsIdentifierButNeverPassword() {
        let result = email.validate(identifier: "  user@example.com \n", password: "  secret  ")
        #expect(result.normalizedIdentifier == "user@example.com")
        #expect(result.isValid)
    }

    @Test func whitespaceOnlyPasswordIsAccepted() {
        // The backend owns password rules; the client must not reject or alter it.
        #expect(email.validate(identifier: "user@example.com", password: "   ").passwordError == nil)
    }

    @Test func usernameModeSkipsEmailFormat() {
        #expect(username.validate(identifier: "jdoe", password: "x").isValid)
        #expect(username.validate(identifier: "", password: "x").identifierError == .identifierRequired(.username))
    }
}

@MainActor
@Suite("LoginViewModel")
struct LoginViewModelTests {
    private func makeViewModel(_ authenticator: MockAuthenticator = MockAuthenticator(), kind: LoginIdentifierKind = .email) -> LoginViewModel {
        LoginViewModel(authenticator: authenticator, identifierKind: kind)
    }

    @Test func invalidInputDoesNotCallAuthenticator() async {
        let authenticator = MockAuthenticator()
        let viewModel = makeViewModel(authenticator)
        viewModel.identifier = "not-an-email"

        let focus = await viewModel.submit()

        #expect(focus == .identifier)
        #expect(viewModel.identifierError == .invalidEmail)
        #expect(viewModel.passwordError == .passwordRequired)
        #expect(authenticator.calls.isEmpty)
    }

    @Test func focusesPasswordWhenOnlyPasswordIsMissing() async {
        let viewModel = makeViewModel()
        viewModel.identifier = "user@example.com"
        #expect(await viewModel.submit() == .password)
    }

    @Test func submitsTrimmedIdentifierAndUntouchedPassword() async {
        let authenticator = MockAuthenticator()
        let viewModel = makeViewModel(authenticator)
        viewModel.identifier = "  user@example.com  "
        viewModel.password = " p@ss word "

        await viewModel.submit()

        #expect(authenticator.calls.count == 1)
        #expect(authenticator.calls.first?.identifier == "user@example.com")
        #expect(authenticator.calls.first?.password == " p@ss word ")
        #expect(viewModel.password.isEmpty) // Cleared from memory after success.
        #expect(viewModel.submissionError == nil)
    }

    @Test func editingClearsFieldError() async {
        let viewModel = makeViewModel()
        await viewModel.submit()
        #expect(viewModel.identifierError != nil)
        viewModel.identifier = "u"
        #expect(viewModel.identifierError == nil)
    }

    @Test func invalidCredentialsShowSpecificMessage() async {
        let authenticator = MockAuthenticator()
        authenticator.error = AuthError.invalidCredentials
        let viewModel = makeViewModel(authenticator)
        viewModel.identifier = "user@example.com"
        viewModel.password = "wrong"

        await viewModel.submit()

        #expect(viewModel.submissionError?.kind == .invalidCredentials)
        #expect(viewModel.submissionError?.message == "The email or password is incorrect.")
        #expect(viewModel.password == "wrong") // Kept so the user can correct it.
        #expect(!viewModel.isSubmitting)
    }

    @Test func networkFailureIsPresented() async {
        let authenticator = MockAuthenticator()
        authenticator.error = APIError.noConnection
        let viewModel = makeViewModel(authenticator)
        viewModel.identifier = "user@example.com"
        viewModel.password = "pw"
        await viewModel.submit()
        #expect(viewModel.submissionError?.kind == .offline)
    }

    @Test func preventsDuplicateSubmission() async {
        let authenticator = MockAuthenticator()
        authenticator.delay = .milliseconds(200)
        let viewModel = makeViewModel(authenticator)
        viewModel.identifier = "user@example.com"
        viewModel.password = "pw"

        let first = Task { await viewModel.submit() }
        await waitUntil { viewModel.isSubmitting }
        #expect(!viewModel.canSubmit)
        #expect(await viewModel.submit() == nil)
        _ = await first.value

        #expect(authenticator.calls.count == 1)
        #expect(!viewModel.isSubmitting)
    }
}

@Suite("Authentication DTOs and mapping")
struct AuthMappingTests {
    @Test func encodesEmailLoginRequest() throws {
        let data = try JSONCoding.makeEncoder().encode(LoginRequestDTO(identifierKind: .email, identifier: "user@example.com", password: "pw"))
        #expect(String(decoding: data, as: UTF8.self) == #"{"email":"user@example.com","password":"pw"}"#)
    }

    @Test func encodesUsernameLoginRequest() throws {
        let data = try JSONCoding.makeEncoder().encode(LoginRequestDTO(identifierKind: .username, identifier: "jdoe", password: "pw"))
        #expect(String(decoding: data, as: UTF8.self) == #"{"password":"pw","username":"jdoe"}"#)
    }

    @Test func decodesDocumentedLoginResponse() throws {
        let json = """
        {"accessToken":"example-access-token","refreshToken":"example-refresh-token","expiresIn":900,"tokenType":"Bearer",
         "user":{"id":"user-123","name":"Example User","email":"user@example.com"}}
        """
        let dto = try JSONCoding.makeDecoder().decode(LoginResponseDTO.self, from: Data(json.utf8))
        let tokens = try AuthMapper.tokens(from: dto.tokens, receivedAt: Fixtures.referenceDate)
        #expect(tokens.accessToken == "example-access-token")
        #expect(tokens.refreshToken == "example-refresh-token")
        #expect(tokens.expiresAt == Fixtures.referenceDate.addingTimeInterval(900))
        #expect(dto.user.map(AuthMapper.user(from:)) == Fixtures.user)
    }

    @Test func rejectsResponsesWithoutAccessToken() throws {
        let dto = try JSONCoding.makeDecoder().decode(TokenResponseDTO.self, from: Data(#"{"refreshToken":"r"}"#.utf8))
        #expect(throws: AuthError.invalidTokenResponse) { try AuthMapper.tokens(from: dto, receivedAt: .now) }
        let empty = try JSONCoding.makeDecoder().decode(TokenResponseDTO.self, from: Data(#"{"accessToken":""}"#.utf8))
        #expect(throws: AuthError.invalidTokenResponse) { try AuthMapper.tokens(from: empty, receivedAt: .now) }
    }

    @Test func rejectsUnsupportedTokenType() throws {
        let dto = try JSONCoding.makeDecoder().decode(TokenResponseDTO.self, from: Data(#"{"accessToken":"a","tokenType":"MAC"}"#.utf8))
        #expect(throws: AuthError.invalidTokenResponse) { try AuthMapper.tokens(from: dto, receivedAt: .now) }
    }

    @Test func toleratesMissingOptionalFields() throws {
        let dto = try JSONCoding.makeDecoder().decode(TokenResponseDTO.self, from: Data(#"{"accessToken":"a","tokenType":"bearer"}"#.utf8))
        let tokens = try AuthMapper.tokens(from: dto, receivedAt: .now)
        #expect(tokens.refreshToken == nil)
        #expect(tokens.expiresAt == nil)
    }

    @Test func userFallsBackToEmailForDisplayName() {
        let user = AuthMapper.user(from: UserDTO(id: "1", name: "  ", email: "a@b.co"))
        #expect(user.name == "a@b.co")
    }

    @Test func tokensNeverAppearInDescriptions() {
        let tokens = AuthTokens(accessToken: "secret-access", refreshToken: "secret-refresh", expiresAt: nil)
        for text in [String(describing: tokens), String(reflecting: tokens), "\(tokens)"] {
            #expect(!text.contains("secret"))
        }
    }

    @Test func repositoryMapsCredentialRejection() async {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, status: 401) }
        let service = TokenRefreshService(store: InMemoryTokenStore(), refresher: MockTokenRefresher())
        let client = AuthenticatedAPIClient(httpClient: TestConfig.httpClient(transport: transport), tokenProvider: service)
        let repository = RemoteAuthRepository(apiClient: client, identifierKind: .email)
        await #expect(throws: AuthError.invalidCredentials) {
            try await repository.login(identifier: "user@example.com", password: "bad")
        }
    }

    @Test func refresherKeepsRefreshTokenWhenServerDoesNotRotate() async throws {
        let transport = StubTransport { request, _ in HTTPStub.response(for: request, json: #"{"accessToken":"new","expiresIn":60}"#) }
        let refresher = RemoteTokenRefresher(httpClient: TestConfig.httpClient(transport: transport), now: { Fixtures.referenceDate })
        let tokens = try await refresher.refreshTokens(using: "refresh-1")
        #expect(tokens.accessToken == "new")
        #expect(tokens.refreshToken == "refresh-1")
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }
}
