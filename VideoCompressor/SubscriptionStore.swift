import StoreKit

enum SubscriptionError: LocalizedError {
    case productUnavailable

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This subscription isn't available yet. It's still being set up on the App Store, try again in a bit."
        }
    }
}

/// Wraps the single "Unlimited" auto-renewable subscription. Free tier covers Compress
/// and Cut up to UsageLimiter's daily cap; Find Duplicates and Split for Stories are
/// subscriber-only. No tiers, no server-side receipt validation - StoreKit2's
/// Transaction.currentEntitlements is Apple-signed and sufficient for a single product.
@MainActor
final class SubscriptionStore: ObservableObject {
    static let shared = SubscriptionStore()
    static let unlimitedProductID = "com.automatrix.videocompressor.unlimited"

    @Published private(set) var isSubscribed = false
    @Published private(set) var product: Product?
    @Published private(set) var didAttemptLoad = false
    @Published var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { [weak self] in await self?.observeTransactionUpdates() }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.unlimitedProductID]).first
        didAttemptLoad = true
    }

    func refreshEntitlement() async {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.unlimitedProductID {
                subscribed = true
            }
        }
        isSubscribed = subscribed
    }

    func purchase() async throws {
        if product == nil {
            await loadProduct()
        }
        guard let product else {
            throw SubscriptionError.productUnavailable
        }
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                await refreshEntitlement()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }
}
