import Foundation

/// A Ben account: enables sync, email forwarding, and backup. Local-first —
/// the account is a promise the backend honours via the email-in Worker.
struct BenAccount: Codable, Equatable, Sendable {
    enum Provider: String, Codable, Sendable {
        case apple, google, password

        var label: String {
            switch self {
            case .apple: "Apple"
            case .google: "Google"
            case .password: "Email"
            }
        }
    }

    let id: String
    let name: String
    let email: String
    let provider: Provider
    let createdAt: Date
    /// The user's personal email-in address: forward a bill, Ben reads it.
    let forwardingAddress: String
}

enum AccountError: Error, LocalizedError {
    case signInFailed
    case cancelled
    case weakPassword
    case emailInUse
    case wrongCredentials
    /// Firebase Console → Authentication → Sign-in method: the provider is off.
    case providerDisabled

    var errorDescription: String? {
        switch self {
        case .signInFailed:
            "That didn't go through. No drama, try again in a tick."
        case .cancelled:
            "No worries — sign in whenever you're ready."
        case .weakPassword:
            "That password's a bit short. Eight characters or more does it."
        case .emailInUse:
            "That email already has a Ben account. Try signing in instead."
        case .wrongCredentials:
            "Email or password didn't match. Have another go."
        case .providerDisabled:
            "That sign-in method isn't switched on yet in Firebase."
        }
    }
}

protocol AccountService: AnyObject, Sendable {
    var account: BenAccount? { get }
    @discardableResult
    func signIn(with provider: BenAccount.Provider) async throws -> BenAccount
    @discardableResult
    func signIn(email: String, password: String, creating: Bool) async throws -> BenAccount
    func signOut()
    /// Proof-of-login for backend calls; nil when signed out.
    func idToken() async throws -> String?
}

/// Local stub: creates and persists a simulated account. Used by previews and
/// UI tests; the live app uses FirebaseAccountService.
final class StubAccountService: AccountService, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "benAccount"
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var account: BenAccount? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BenAccount.self, from: data)
    }

    @discardableResult
    func signIn(with provider: BenAccount.Provider) async throws -> BenAccount {
        if let existing = account { return existing }
        // Simulated provider handshake — instant, deterministic.
        let id = UUID().uuidString
        let account = BenAccount(
            id: id,
            name: "Ben Tester",
            email: provider == .apple ? "you@privaterelay.appleid.com" : "you@gmail.com",
            provider: provider,
            createdAt: .now,
            forwardingAddress: Self.forwardingAddress(for: id)
        )
        persist(account)
        return account
    }

    @discardableResult
    func signIn(email: String, password: String, creating: Bool) async throws -> BenAccount {
        if let existing = account { return existing }
        let id = UUID().uuidString
        let account = BenAccount(
            id: id,
            name: email.components(separatedBy: "@").first ?? "Ben Tester",
            email: email,
            provider: .password,
            createdAt: .now,
            forwardingAddress: Self.forwardingAddress(for: id)
        )
        persist(account)
        return account
    }

    func signOut() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }

    func idToken() async throws -> String? {
        account == nil ? nil : "stub-token"
    }

    private func persist(_ account: BenAccount) {
        lock.lock()
        defer { lock.unlock() }
        if let data = try? JSONEncoder().encode(account) {
            defaults.set(data, forKey: key)
        }
    }

    /// Deterministic personal address: bills-<8 chars of the account id>@in.benandbill.app.
    static func forwardingAddress(for accountID: String) -> String {
        let slug = accountID.lowercased().replacingOccurrences(of: "-", with: "").prefix(8)
        return "bills-\(slug)@in.benandbill.app"
    }
}
