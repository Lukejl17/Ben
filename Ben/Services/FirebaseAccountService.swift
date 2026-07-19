import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import UIKit

/// Real accounts via Firebase Authentication: Sign in with Apple, Google
/// (Firebase's web flow — no extra SDK), and email/password. After any
/// successful sign-in we register with the email-in Worker, which mints the
/// user's permanent forwarding address.
///
/// HUMAN: Sign in with Apple lights up once the Apple Developer membership is
/// approved and the capability is on the App ID. Google + email/password work
/// before then.
final class FirebaseAccountService: NSObject, AccountService, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "benAccount"
    private let lock = NSLock()
    private let emailIn: any EmailInFetching

    // Held for the duration of the Apple sign-in sheet.
    private var appleContinuation: CheckedContinuation<ASAuthorization, Error>?
    private var appleNonce: String?

    init(defaults: UserDefaults = .standard, emailIn: any EmailInFetching = EmailInClient()) {
        self.defaults = defaults
        self.emailIn = emailIn
        super.init()
    }

    var account: BenAccount? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BenAccount.self, from: data)
    }

    func idToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        return try await user.getIDToken()
    }

    @discardableResult
    func signIn(with provider: BenAccount.Provider) async throws -> BenAccount {
        switch provider {
        case .apple:
            return try await signInWithApple()
        case .google:
            return try await signInWithGoogle()
        case .password:
            throw AccountError.signInFailed // use signIn(email:password:creating:)
        }
    }

    @discardableResult
    func signIn(email: String, password: String, creating: Bool) async throws -> BenAccount {
        do {
            let result: AuthDataResult
            if creating {
                result = try await Auth.auth().createUser(withEmail: email, password: password)
            } else {
                result = try await Auth.auth().signIn(withEmail: email, password: password)
            }
            return try await finishSignIn(user: result.user, provider: .password)
        } catch let error as NSError where error.domain == AuthErrorDomain {
            throw mapAuthError(error)
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: key)
    }

    // MARK: - Apple

    private func signInWithApple() async throws -> BenAccount {
        let nonce = Self.randomNonce()
        appleNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        let authorization: ASAuthorization = try await withCheckedThrowingContinuation { continuation in
            appleContinuation = continuation
            controller.performRequests()
        }

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let tokenString = String(data: tokenData, encoding: .utf8)
        else { throw AccountError.signInFailed }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        let result = try await Auth.auth().signIn(with: firebaseCredential)
        return try await finishSignIn(user: result.user, provider: .apple)
    }

    // MARK: - Google (Firebase web flow, no GoogleSignIn SDK)

    private func signInWithGoogle() async throws -> BenAccount {
        let provider = OAuthProvider(providerID: "google.com")
        provider.scopes = ["email", "profile"]
        do {
            let credential = try await provider.credential(with: nil)
            let result = try await Auth.auth().signIn(with: credential)
            return try await finishSignIn(user: result.user, provider: .google)
        } catch let error as NSError where error.domain == AuthErrorDomain {
            throw mapAuthError(error)
        }
    }

    // MARK: - Shared tail: register with the mailroom, persist locally

    private func finishSignIn(user: User, provider: BenAccount.Provider) async throws -> BenAccount {
        let token = try await user.getIDToken()
        let forwardingAddress = try await emailIn.register(idToken: token)

        let account = BenAccount(
            id: user.uid,
            name: user.displayName ?? user.email?.components(separatedBy: "@").first ?? "You",
            email: user.email ?? "",
            provider: provider,
            createdAt: user.metadata.creationDate ?? .now,
            forwardingAddress: forwardingAddress
        )
        persist(account)
        return account
    }

    private func persist(_ account: BenAccount) {
        lock.lock()
        defer { lock.unlock() }
        if let data = try? JSONEncoder().encode(account) {
            defaults.set(data, forKey: key)
        }
    }

    private func mapAuthError(_ error: NSError) -> AccountError {
        switch AuthErrorCode(rawValue: error.code) {
        case .weakPassword: .weakPassword
        case .emailAlreadyInUse: .emailInUse
        case .wrongPassword, .invalidCredential, .userNotFound, .invalidEmail: .wrongCredentials
        case .webContextCancelled: .cancelled
        default: .signInFailed
        }
    }

    // MARK: - Nonce helpers (Apple sign-in replay protection)

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension FirebaseAccountService: ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        appleContinuation?.resume(returning: authorization)
        appleContinuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController, didCompleteWithError error: Error
    ) {
        let isCancel = (error as? ASAuthorizationError)?.code == .canceled
        appleContinuation?.resume(throwing: isCancel ? AccountError.cancelled : error)
        appleContinuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
