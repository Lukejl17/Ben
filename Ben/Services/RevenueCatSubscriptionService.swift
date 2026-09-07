import Foundation
import OSLog
import os
import RevenueCat

/// Product IDs and entitlement — must match App Store Connect + RevenueCat.
enum RevenueCatConfig {
    static let entitlementID = "ben_pro"
    static let annualProductID = "ben_pro_annual"
    static let monthlyProductID = "ben_pro_monthly"

    /// Test Store public key from the Ben project (debug / simulator).
    /// HUMAN: paste the Apple public SDK key (`appl_…`) for TestFlight/App Store.
    #if DEBUG
    static let publicAPIKey = "test_gFjsjDujEqiMmhPUOIgQvtqFqzg"
    #else
    static let publicAPIKey = ""
    #endif

    static var resolvedAPIKey: String {
        if let plist = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String {
            let trimmed = plist.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.hasPrefix("$(") { return trimmed }
        }
        return publicAPIKey
    }

    static var isConfigured: Bool { !resolvedAPIKey.isEmpty }
}

/// Live entitlements via RevenueCat + StoreKit. Configure once at launch.
final class RevenueCatSubscriptionService: NSObject, SubscriptionService, PurchasesDelegate, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.repertoirestudio.Ben", category: "subscription")
    private let reminderDayKey = "trial.preChargeReminderDaysBeforeEnd"
    private let defaults: UserDefaults
    private let calendar: Calendar

    private struct Snapshot {
        var latestState: TrialState = .notStarted
        var cachedAnnual: Package?
        var cachedMonthly: Package?
        var cachedPricing: PlanPricing = .fallback
    }

    private let snapshot = OSAllocatedUnfairLock(initialState: Snapshot())

    var usesRemoteEntitlements: Bool { true }

    var pricing: PlanPricing {
        snapshot.withLock { $0.cachedPricing }
    }

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        super.init()
        Self.configureIfNeeded()
        if Purchases.isConfigured {
            Purchases.shared.delegate = self
        }
    }

    static func configureIfNeeded(apiKey: String = RevenueCatConfig.resolvedAPIKey) {
        guard !Purchases.isConfigured else { return }
        guard !apiKey.isEmpty else { return }
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
        let configuration = Configuration.builder(withAPIKey: apiKey)
            .with(storeKitVersion: .storeKit2)
            .with(entitlementVerificationMode: .informational)
            .build()
        Purchases.configure(with: configuration)
    }

    func startTrial(preChargeReminderDaysBeforeEnd: Int, now: Date) {
        defaults.set(preChargeReminderDaysBeforeEnd, forKey: reminderDayKey)
    }

    func state(now: Date = .now) -> TrialState {
        _ = now
        return snapshot.withLock { $0.latestState }
    }

    var isEntitled: Bool { state().isEntitled }

    var preChargeReminderDaysBeforeEnd: Int? {
        defaults.object(forKey: reminderDayKey) as? Int
    }

    func refresh() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.customerInfo()
            apply(info)
        } catch {
            logger.error("customerInfo failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshOfferings()
    }

    func purchase(_ plan: SubscriptionPlan) async throws -> PurchaseOutcome {
        guard Purchases.isConfigured else { throw SubscriptionError.notConfigured }
        let package = try await package(for: plan)
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            if result.userCancelled { return .cancelled }
            return snapshot.withLock { $0.latestState.isEntitled } ? .entitled : .cancelled
        } catch {
            if revenueCatCode(error) == .purchaseCancelledError {
                return .cancelled
            }
            if revenueCatCode(error) == .productAlreadyPurchasedError {
                await refresh()
                if snapshot.withLock({ $0.latestState.isEntitled }) { return .entitled }
            }
            throw mapPurchaseError(error)
        }
    }

    func restore() async throws -> PurchaseOutcome {
        guard Purchases.isConfigured else { throw SubscriptionError.notConfigured }
        do {
            let info = try await Purchases.shared.restorePurchases()
            apply(info)
            guard snapshot.withLock({ $0.latestState.isEntitled }) else { throw SubscriptionError.notEntitled }
            return .entitled
        } catch let error as SubscriptionError {
            throw error
        } catch {
            throw mapPurchaseError(error)
        }
    }

    func identify(userID: String) async {
        guard Purchases.isConfigured, !userID.isEmpty else { return }
        do {
            let result = try await Purchases.shared.logIn(userID)
            apply(result.customerInfo)
        } catch {
            logger.error("logIn failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        do {
            let synced = try await Purchases.shared.syncPurchases()
            apply(synced)
        } catch {
            logger.error("syncPurchases failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func logOutPurchaser() async {
        guard Purchases.isConfigured else { return }
        do {
            let info = try await Purchases.shared.logOut()
            apply(info)
        } catch {
            logger.error("logOut failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        apply(customerInfo)
    }

    private func refreshOfferings() async {
        guard Purchases.isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            cache(offerings)
        } catch {
            logger.error("offerings failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func cache(_ offerings: Offerings) {
        guard let current = offerings.current else { return }
        let annual = current.annual
            ?? current.availablePackages.first { $0.storeProduct.productIdentifier == RevenueCatConfig.annualProductID }
            ?? current.availablePackages.first { $0.packageType == .annual }
        let monthly = current.monthly
            ?? current.availablePackages.first { $0.storeProduct.productIdentifier == RevenueCatConfig.monthlyProductID }
            ?? current.availablePackages.first { $0.packageType == .monthly }
        let nextPricing = Self.pricing(annual: annual, monthly: monthly)
        snapshot.withLock {
            $0.cachedAnnual = annual
            $0.cachedMonthly = monthly
            $0.cachedPricing = nextPricing
        }
        notify()
    }

    private func package(for plan: SubscriptionPlan) async throws -> Package {
        if let cached = snapshot.withLock({ state -> Package? in
            switch plan {
            case .annual: state.cachedAnnual
            case .monthly: state.cachedMonthly
            }
        }) {
            return cached
        }

        let offerings: Offerings
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            throw SubscriptionError.offeringsUnavailable
        }
        cache(offerings)
        let match = snapshot.withLock { state -> Package? in
            switch plan {
            case .annual: state.cachedAnnual
            case .monthly: state.cachedMonthly
            }
        }
        guard let match else { throw SubscriptionError.packageMissing }
        return match
    }

    private func apply(_ info: CustomerInfo) {
        let mapped = Self.map(info, calendar: calendar)
        snapshot.withLock { $0.latestState = mapped }
        notify()
    }

    private func notify() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .benSubscriptionDidChange, object: nil)
        }
    }

    static func map(_ info: CustomerInfo, now: Date = .now, calendar: Calendar = .current) -> TrialState {
        guard let entitlement = info.entitlements[RevenueCatConfig.entitlementID] else {
            return .notStarted
        }
        guard entitlement.isActive else { return .lapsed }
        let period: SubscriptionPeriodKind = switch entitlement.periodType {
        case .trial: .trial
        case .intro: .intro
        default: .normal
        }
        return EntitlementMapping.state(
            isActive: true,
            expirationDate: entitlement.expirationDate,
            period: period,
            now: now,
            calendar: calendar
        )
    }

    static func pricing(annual: Package?, monthly: Package?) -> PlanPricing {
        var next = PlanPricing.fallback
        if let annual {
            let product = annual.storeProduct
            next.annualPrice = product.localizedPriceString
            if let perMonth = product.localizedPricePerMonth {
                next.annualPerMonth = perMonth
            }
            next.annualHasIntro = product.introductoryDiscount != nil
        }
        if let monthly {
            next.monthlyPrice = monthly.storeProduct.localizedPriceString
        }
        return next
    }

    private func revenueCatCode(_ error: Error) -> ErrorCode? {
        if let code = error as? ErrorCode { return code }
        let ns = error as NSError
        let domain = ns.domain
        guard domain.contains("Purchases") || domain.contains("RevenueCat") else { return nil }
        return ErrorCode(rawValue: ns.code)
    }

    private func mapPurchaseError(_ error: Error) -> SubscriptionError {
        guard let code = revenueCatCode(error) else {
            return .failed("That didn't go through. No drama, try again in a tick.")
        }
        switch code {
        case .purchaseNotAllowedError:
            return .failed("Purchases aren't allowed on this device.")
        case .purchaseInvalidError:
            return .failed("That purchase didn't go through. Check the payment method.")
        case .networkError, .offlineConnectionError:
            return .failed("Couldn't reach the App Store. Try again in a moment.")
        case .productNotAvailableForPurchaseError, .productRequestTimedOut:
            return .packageMissing
        case .paymentPendingError:
            return .paymentPending
        case .receiptAlreadyInUseError, .receiptInUseByOtherSubscriberError, .purchaseBelongsToOtherUser:
            return .failed("That Apple ID already has Ben Pro on another account. Restore, or sign in there.")
        case .storeProblemError:
            return .failed("The App Store had a wobble. Try again in a moment.")
        default:
            return .failed("That didn't go through. No drama, try again in a tick.")
        }
    }
}
