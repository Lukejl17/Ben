import Foundation
import Observation

/// A pending forwarded attachment with a human-readable label for Home.
struct PendingBillPreview: Identifiable, Equatable, Sendable {
    let item: PendingEmailBill
    /// Issuer (preferred), else subject, else a calm fallback.
    var title: String
    var subtitle: String
    var isEnriching: Bool

    var id: String { item.key }
}

/// Shared mailroom shelf for Home (and the email-in address sheet while waiting).
/// Home refreshes on appear / foreground / pull; the address sheet may poll briefly.
@Observable
@MainActor
final class PendingEmailMonitor {
    private(set) var items: [PendingEmailBill] = []
    private(set) var previews: [PendingBillPreview] = []
    private(set) var isLoading = false
    private(set) var lastError: String?
    private var pollTask: Task<Void, Never>?
    private var enrichTask: Task<Void, Never>?
    /// OCR labels keyed by R2 object key — survives list refreshes in-session.
    private var labelCache: [String: (title: String, subtitle: String)] = [:]

    var count: Int { items.count }
    var hasPending: Bool { !items.isEmpty }

    /// Drop the in-memory shelf (sign-out / account switch).
    func clear() {
        stopPolling()
        enrichTask?.cancel()
        enrichTask = nil
        items = []
        previews = []
        labelCache = [:]
        lastError = nil
        isLoading = false
    }

    func refresh(
        accounts: any AccountService,
        emailIn: any EmailInFetching,
        parser: (any BillParsing)? = nil
    ) async {
        guard accounts.account != nil else {
            items = []
            previews = []
            lastError = nil
            return
        }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            guard let token = try await accounts.idToken() else {
                items = []
                previews = []
                return
            }
            items = try await emailIn.pending(idToken: token)
            rebuildPreviews()
            if let parser {
                scheduleEnrichment(token: token, emailIn: emailIn, parser: parser)
            }
        } catch {
            lastError = "Couldn't check for new bills just now."
        }
    }

    /// Drop an unwanted forward (signature chrome, wrong mail, etc.).
    func dismiss(
        key: String,
        accounts: any AccountService,
        emailIn: any EmailInFetching
    ) async {
        do {
            guard let token = try await accounts.idToken() else { return }
            try await emailIn.claim(key: key, idToken: token)
            items.removeAll { $0.key == key }
            labelCache.removeValue(forKey: key)
            rebuildPreviews()
        } catch {
            lastError = "Couldn't remove that one. Try again in a tick."
        }
    }

    func startPolling(
        accounts: any AccountService,
        emailIn: any EmailInFetching,
        parser: (any BillParsing)? = nil,
        every interval: Duration = .seconds(3)
    ) {
        stopPolling()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh(accounts: accounts, emailIn: emailIn, parser: parser)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Labels

    private func rebuildPreviews() {
        previews = items.map { item in
            if let cached = labelCache[item.key] {
                return PendingBillPreview(
                    item: item, title: cached.title, subtitle: cached.subtitle, isEnriching: false
                )
            }
            let fallback = Self.fallbackLabel(for: item)
            return PendingBillPreview(
                item: item, title: fallback.title, subtitle: fallback.subtitle, isEnriching: true
            )
        }
    }

    private static func fallbackLabel(for item: PendingEmailBill) -> (title: String, subtitle: String) {
        let subject = item.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let from = item.from.trimmingCharacters(in: .whitespacesAndNewlines)
        if !subject.isEmpty {
            return (subject, from.isEmpty ? "Tap to confirm" : from)
        }
        if !from.isEmpty {
            return (from, "Tap to confirm")
        }
        return ("Bill", "Reading it…")
    }

    private func scheduleEnrichment(
        token: String,
        emailIn: any EmailInFetching,
        parser: any BillParsing
    ) {
        enrichTask?.cancel()
        let keysNeedingWork = items.map(\.key).filter { labelCache[$0] == nil }
        guard !keysNeedingWork.isEmpty else { return }
        enrichTask = Task {
            for key in keysNeedingWork {
                if Task.isCancelled { return }
                guard let item = items.first(where: { $0.key == key }) else { continue }
                do {
                    let data = try await emailIn.blob(key: key, idToken: token)
                    let parsed = try? await parser.parse(data)
                    let label = Self.label(from: parsed, item: item)
                    labelCache[key] = label
                    rebuildPreviews()
                } catch {
                    // Leave fallback; user can still open or remove.
                    labelCache[key] = Self.fallbackLabel(for: item)
                    rebuildPreviews()
                }
            }
        }
    }

    private static func label(
        from parsed: ParsedBill?, item: PendingEmailBill
    ) -> (title: String, subtitle: String) {
        let issuer = parsed?.issuer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let subject = item.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String
        if !issuer.isEmpty {
            title = issuer
        } else if !subject.isEmpty {
            title = subject
        } else {
            let from = item.from.trimmingCharacters(in: .whitespacesAndNewlines)
            title = from.isEmpty ? "Bill" : from
        }

        var parts: [String] = []
        if let amount = parsed?.amount {
            parts.append(amount.formatted(.currency(code: "AUD")))
        }
        if let due = parsed?.dueDate {
            parts.append("due \(due.formatted(.dateTime.day().month(.abbreviated)))")
        }
        let subtitle = parts.isEmpty ? "Tap to confirm" : parts.joined(separator: " · ")
        return (title, subtitle)
    }
}
