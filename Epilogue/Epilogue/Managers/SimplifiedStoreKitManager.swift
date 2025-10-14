import SwiftUI
import StoreKit
import Combine

// MARK: - Simplified StoreKit Manager
@MainActor
class SimplifiedStoreKitManager: ObservableObject {
    static let shared = SimplifiedStoreKitManager()

    // Product IDs
    private let monthlyID = "com.epilogue.plus.monthly"  // $7.99
    private let annualID = "com.epilogue.plus.annual"    // $67.00

    // State
    @Published var isPlus = false
    @Published var conversationsUsed = 0
    @Published var monthlyProduct: Product?
    @Published var annualProduct: Product?
    @Published var isLoading = false
    @Published var purchaseError: String?

    private var updateListenerTask: Task<Void, Error>?

    private init() {
        // Load conversation count from UserDefaults
        loadConversationCount()

        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        // Load products and check status
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        purchaseError = nil

        do {
            let products = try await Product.products(for: [monthlyID, annualID])

            for product in products {
                switch product.id {
                case monthlyID:
                    monthlyProduct = product
                case annualID:
                    annualProduct = product
                default:
                    break
                }
            }

            print("✅ Loaded products: monthly=\(monthlyProduct != nil), annual=\(annualProduct != nil)")
        } catch {
            print("❌ Failed to load products: \(error)")
            purchaseError = "Unable to load subscriptions. Please try again."
        }
        isLoading = false
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check verification
                let transaction = try checkVerified(verification)

                // Update subscription status
                await checkSubscriptionStatus()

                // Finish transaction
                await transaction.finish()

                isLoading = false
                print("✅ Purchase successful: \(product.id)")
                return true

            case .userCancelled:
                isLoading = false
                print("⚠️ Purchase cancelled by user")
                return false

            case .pending:
                isLoading = false
                purchaseError = "Purchase is pending approval"
                print("⏳ Purchase pending")
                return false

            @unknown default:
                isLoading = false
                return false
            }
        } catch StoreError.failedVerification {
            isLoading = false
            purchaseError = "Purchase verification failed. Please try again."
            print("❌ Purchase verification failed")
            return false
        } catch {
            isLoading = false
            purchaseError = error.localizedDescription
            print("❌ Purchase failed: \(error)")
            return false
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            isLoading = false
            print("✅ Purchases restored")
        } catch {
            isLoading = false
            purchaseError = "Unable to restore purchases. Please try again."
            print("❌ Restore failed: \(error)")
        }
    }

    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() async {
        var hasActiveSubscription = false

        // Check subscription status for both products
        if let monthlyProduct = monthlyProduct {
            if let status = try? await monthlyProduct.subscription?.status {
                for statusItem in status {
                    if case .verified(let renewal) = statusItem.renewalInfo,
                       case .verified(let transaction) = statusItem.transaction {
                        if renewal.currentProductID == monthlyID && transaction.revocationDate == nil {
                            hasActiveSubscription = true
                            break
                        }
                    }
                }
            }
        }

        if !hasActiveSubscription, let annualProduct = annualProduct {
            if let status = try? await annualProduct.subscription?.status {
                for statusItem in status {
                    if case .verified(let renewal) = statusItem.renewalInfo,
                       case .verified(let transaction) = statusItem.transaction {
                        if renewal.currentProductID == annualID && transaction.revocationDate == nil {
                            hasActiveSubscription = true
                            break
                        }
                    }
                }
            }
        }

        isPlus = hasActiveSubscription
        print("📊 Subscription status: \(isPlus ? "PLUS" : "FREE")")
    }

    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)

                    // Update subscription status
                    await self.checkSubscriptionStatus()

                    // Finish transaction
                    await transaction.finish()
                } catch {
                    print("❌ Transaction update failed: \(error)")
                }
            }
        }
    }

    // MARK: - Verify Transaction
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Conversation Counting
    func conversationsRemaining() -> Int? {
        guard !isPlus else { return nil }
        return max(0, 2 - conversationsUsed)
    }

    func canStartConversation() -> Bool {
        return isPlus || conversationsUsed < 2
    }

    func recordConversation() {
        guard !isPlus else { return }

        conversationsUsed += 1
        UserDefaults.standard.set(conversationsUsed, forKey: "conversationsUsed")
        UserDefaults.standard.set(Date(), forKey: "lastConversationDate")

        print("📝 Recorded conversation: \(conversationsUsed)/2 used")
    }

    func resetMonthlyCount() {
        conversationsUsed = 0
        UserDefaults.standard.set(0, forKey: "conversationsUsed")
        UserDefaults.standard.set(Date(), forKey: "lastResetDate")
        print("🔄 Reset monthly conversation count")
    }

    // MARK: - Private Helpers
    private func loadConversationCount() {
        conversationsUsed = UserDefaults.standard.integer(forKey: "conversationsUsed")

        // Check if we need to reset (new month)
        if let lastReset = UserDefaults.standard.object(forKey: "lastResetDate") as? Date {
            let calendar = Calendar.current
            if !calendar.isDate(lastReset, equalTo: Date(), toGranularity: .month) {
                resetMonthlyCount()
            }
        } else {
            // First time - set reset date
            UserDefaults.standard.set(Date(), forKey: "lastResetDate")
        }
    }

    // MARK: - Formatted Prices
    var monthlyPrice: String? {
        monthlyProduct?.displayPrice
    }

    var annualPrice: String? {
        annualProduct?.displayPrice
    }

    var annualMonthlyPrice: String? {
        guard let annual = annualProduct else { return nil }
        let monthlyEquivalent = (annual.price as Decimal) / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = annual.priceFormatStyle.locale
        return formatter.string(from: monthlyEquivalent as NSNumber)
    }
}

// MARK: - Store Error
enum StoreError: Error {
    case failedVerification
}
