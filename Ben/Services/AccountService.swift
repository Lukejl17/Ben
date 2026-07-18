import Foundation

/// A Ben account: enables sync, email forwarding, and backup. Local-first —
/// the account is a promise the backend will honour later.
struct BenAccount: Codable, Equatable, Sendable {
    enum Provider: String, Codable, Sendable {
        case apple, google

        var label: String {
            switch self {
            case .apple: "Apple"
            case .google: "Google"
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

    var errorDescription: String? {
        "That didn't go through. No drama, try again in a tick."
    }
}

protocol AccountService: AnyObject, Sendable {
    var account: BenAccount? { get }
    @discardableResult
    func signIn(with provider: BenAccount.Provider) async throws -> BenAccount
    func signOut()
}

/// Local stub: creates and persists a simulated account.
/// HUMAN: replace internals with real Sign in with Apple (capability +
/// entitlement) and Google Sign-In SDK (OAuth client ID). The protocol,
/// call sites, and stored shape stay as-is.
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

    func signOut() {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
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
