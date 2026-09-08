import Foundation

/// Talks to the Ben email-in backend (Cloudflare Worker). Every call carries
/// the user's Firebase ID token — the backend only ever returns that user's
/// own bills. See backend/email-in/README.md for the endpoint contract.
struct PendingEmailBill: Codable, Identifiable, Equatable, Sendable {
    let key: String
    let uploaded: Date
    let size: Int
    let from: String
    let subject: String
    let contentType: String

    var id: String { key }
}

enum EmailInError: Error, LocalizedError {
    case notSignedIn
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            "Sign in first and your address is ready to go."
        case .server:
            "Couldn't reach Ben's mailroom. It'll be there when you try again."
        }
    }
}

protocol EmailInFetching: Sendable {
    /// Mints (or returns) the user's forwarding address on the backend.
    func register(idToken: String) async throws -> String
    /// Bills waiting to be confirmed.
    func pending(idToken: String) async throws -> [PendingEmailBill]
    /// The raw bytes of one waiting bill.
    func blob(key: String, idToken: String) async throws -> Data
    /// Delete a bill after the user has confirmed it in the app.
    func claim(key: String, idToken: String) async throws
}

struct EmailInClient: EmailInFetching {
    var baseURL = URL(string: "https://ben-email-in.luke-9e7.workers.dev")!
    var session: URLSession = .shared

    func register(idToken: String) async throws -> String {
        struct RegisterResponse: Codable { let forwardingAddress: String }
        let data = try await send("POST", path: "/register", idToken: idToken)
        return try JSONDecoder().decode(RegisterResponse.self, from: data).forwardingAddress
    }

    func pending(idToken: String) async throws -> [PendingEmailBill] {
        struct PendingResponse: Codable { let items: [PendingEmailBill] }
        let data = try await send("GET", path: "/pending", idToken: idToken)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PendingResponse.self, from: data).items
    }

    func blob(key: String, idToken: String) async throws -> Data {
        try await send("GET", path: "/blob", query: [URLQueryItem(name: "key", value: key)],
                       idToken: idToken)
    }

    func claim(key: String, idToken: String) async throws {
        let body = try JSONEncoder().encode(["key": key])
        _ = try await send("POST", path: "/claim", body: body, idToken: idToken)
    }

    private func send(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        idToken: String
    ) async throws -> Data {
        var components = URLComponents(
            url: baseURL.appending(path: path), resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw EmailInError.server(status) }
        return data
    }
}

/// Previews and tests: a mailroom with nothing in it (or canned items).
struct MockEmailInClient: EmailInFetching {
    var items: [PendingEmailBill] = []
    var blobData = Data()

    func register(idToken: String) async throws -> String {
        "bills-preview@in.benandbill.app"
    }

    func pending(idToken: String) async throws -> [PendingEmailBill] { items }

    func blob(key: String, idToken: String) async throws -> Data { blobData }

    func claim(key: String, idToken: String) async throws {}
}
