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

            // Validate that we loaded at least one product
            if monthlyProduct == nil && annualProduct == nil {
                purchaseError = "No subscriptions available. Please check your connection and try again."
                #if DEBUG
                print("⚠️ No products loaded from App Store")
                #endif
            } else {
                #if DEBUG
                print("✅ Loaded products: monthly=\(monthlyProduct != nil), annual=\(annualProduct != nil)")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to load products: \(error)")
            #endif
            purchaseError = "Unable to load subscriptions. Please check your connection and try again."
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
                var transaction: StoreKit.Transaction?

                do {
                    // Check verification
                    transaction = try checkVerified(verification)

                    // Update subscription status
                    await checkSubscriptionStatus()

                    // Always finish transaction to prevent it from being re-delivered
                    await transaction?.finish()

                    isLoading = false
                    #if DEBUG
                    print("✅ Purchase successful: \(product.id)")
                    #endif
                    return true
                } catch {
                    // Even if verification fails, finish the transaction
                    await transaction?.finish()

                    isLoading = false
                    purchaseError = "Purchase verification failed. Please contact support if charged."
                    #if DEBUG
                    print("❌ Purchase verification failed but transaction finished")
                    #endif
                    return false
                }

            case .userCancelled:
                isLoading = false
                purchaseError = nil  // Clear any previous errors
                #if DEBUG
                print("⚠️ Purchase cancelled by user")
                #endif
                return false

            case .pending:
                isLoading = false
                purchaseError = "Purchase is pending approval. You'll be notified when it's ready."
                #if DEBUG
                print("⏳ Purchase pending")
                #endif
                return false

            @unknown default:
                isLoading = false
                purchaseError = "Unknown purchase state. Please try again."
                #if DEBUG
                print("⚠️ Unknown purchase result")
                #endif
                return false
            }
        } catch StoreError.failedVerification {
            isLoading = false
            purchaseError = "Purchase verification failed. Please contact support if charged."
            #if DEBUG
            print("❌ Purchase verification failed")
            #endif
            return false
        } catch let error as StoreKitError {
            isLoading = false
            // Handle specific StoreKit errors
            switch error {
            case .networkError:
                purchaseError = "Network error. Please check your connection and try again."
            case .userCancelled:
                purchaseError = nil  // User intentionally cancelled
            case .systemError:
                purchaseError = "System error. Please try again later."
            case .notAvailableInStorefront:
                purchaseError = "This subscription is not available in your region."
            default:
                purchaseError = "Purchase failed: \(error.localizedDescription)"
            }
            #if DEBUG
            print("❌ StoreKit error: \(error)")
            #endif
            return false
        } catch {
            isLoading = false
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            #if DEBUG
            print("❌ Purchase failed: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            // Sync with App Store to restore previous purchases
            try await AppStore.sync()

            // Check if we now have an active subscription
            let wasPlus = isPlus
            await checkSubscriptionStatus()

            isLoading = false

            if isPlus {
                // Successfully restored an active subscription
                #if DEBUG
                print("✅ Purchases restored - user is now Plus")
                #endif
            } else if wasPlus == isPlus && !isPlus {
                // No active subscription found
                purchaseError = "No active subscriptions found. If you believe this is an error, please contact support."
                #if DEBUG
                print("⚠️ Restore complete but no active subscriptions found")
                #endif
            } else {
                #if DEBUG
                print("✅ Restore complete - subscription status unchanged")
                #endif
            }
        } catch {
            isLoading = false
            purchaseError = "Unable to restore purchases. Please check your connection and try again."
            #if DEBUG
            print("❌ Restore failed: \(error)")
            #endif
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
        #if DEBUG
        print("📊 Subscription status: \(isPlus ? "PLUS" : "FREE")")
        #endif
    }

    // MARK: - Listen for Transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in StoreKit.Transaction.updates {
                var transaction: StoreKit.Transaction?

                do {
                    // Verify transaction
                    transaction = try self.checkVerified(result)

                    // Update subscription status (handles expiration gracefully)
                    await self.checkSubscriptionStatus()

                    // Always finish transaction to acknowledge receipt
                    await transaction?.finish()

                    #if DEBUG
                    print("✅ Transaction update processed and finished")
                    #endif
                } catch {
                    // Even if verification fails, try to finish the transaction
                    await transaction?.finish()

                    #if DEBUG
                    print("❌ Transaction update failed: \(error), but transaction finished")
                    #endif
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
        return max(0, 8 - conversationsUsed)
    }

    func canStartConversation() -> Bool {
        return isPlus || conversationsUsed < 8
    }

    func recordConversation() {
        guard !isPlus else { return }

        conversationsUsed += 1
        UserDefaults.standard.set(conversationsUsed, forKey: "conversationsUsed")
        UserDefaults.standard.set(Date(), forKey: "lastConversationDate")

        #if DEBUG
        print("📝 Recorded conversation: \(conversationsUsed)/8 used")
        #endif
    }

    func resetMonthlyCount() {
        conversationsUsed = 0
        UserDefaults.standard.set(0, forKey: "conversationsUsed")
        UserDefaults.standard.set(Date(), forKey: "lastResetDate")
        #if DEBUG
        print("🔄 Reset monthly conversation count")
        #endif
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
