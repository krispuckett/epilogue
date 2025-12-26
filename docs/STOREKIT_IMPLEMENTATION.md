# StoreKit 2 Implementation Specification

> Technical reference for Epilogue's subscription system

## Overview

Epilogue uses StoreKit 2 (iOS 15+) for subscription management. The implementation follows Apple's best practices for auto-renewable subscriptions.

**Primary File:** `Epilogue/Managers/SimplifiedStoreKitManager.swift`

---

## Product Configuration

### App Store Connect Setup

| Product ID | Type | Price | Duration |
|------------|------|-------|----------|
| `com.epilogue.plus.monthly` | Auto-renewable | $7.99 | 1 month |
| `com.epilogue.plus.annual` | Auto-renewable | $67.00 | 1 year |

### Future Products (Not Yet Configured)

| Product ID | Type | Price | Duration |
|------------|------|-------|----------|
| `com.epilogue.plus.trial` | Auto-renewable with trial | $7.99 | 7-day trial → monthly |
| `com.epilogue.plus.lifetime` | Non-consumable | $199.00 | Forever |
| `com.epilogue.family.monthly` | Auto-renewable | $12.99 | 1 month |

### Subscription Group

```
Group Name: Epilogue Subscriptions
Group ID: [Your Group ID from App Store Connect]
Level Order:
  1. com.epilogue.plus.annual (highest)
  2. com.epilogue.plus.monthly
  3. com.epilogue.plus.trial (if added)
```

---

## Architecture

### SimplifiedStoreKitManager

```swift
@MainActor
class SimplifiedStoreKitManager: ObservableObject {
    static let shared = SimplifiedStoreKitManager()

    // Published State
    @Published var isPlus = false
    @Published var conversationsUsed = 0
    @Published var monthlyProduct: Product?
    @Published var annualProduct: Product?
    @Published var isLoading = false
    @Published var purchaseError: String?

    // Core Methods
    func loadProducts() async
    func purchase(_ product: Product) async -> Bool
    func restorePurchases() async
    func checkSubscriptionStatus() async

    // Usage Tracking
    func conversationsRemaining() -> Int?
    func canStartConversation() -> Bool
    func recordConversation()
    func resetMonthlyCount()
}
```

### State Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      App Launch                              │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  1. loadConversationCount()                                  │
│     - Check Gandalf mode (debug bypass)                     │
│     - Load from UserDefaults                                │
│     - Check if month has changed → reset if needed          │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  2. listenForTransactions()                                  │
│     - Start background Task                                  │
│     - Listen to Transaction.updates                         │
│     - Auto-handle renewals, expirations, refunds            │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  3. loadProducts()                                           │
│     - Fetch from App Store (with 3x retry)                  │
│     - Populate monthlyProduct, annualProduct                │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  4. checkSubscriptionStatus()                                │
│     - Check both products for active entitlement            │
│     - Set isPlus = true/false                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Purchase Flow

### Happy Path

```swift
// User taps "Continue with Epilogue+"
func handleContinue() {
    Task {
        let product = selectedInterval == .annual
            ? storeKit.annualProduct
            : storeKit.monthlyProduct

        guard let product = product else {
            // Show error, retry loading
            return
        }

        let success = await storeKit.purchase(product)

        if success {
            // Show celebration UI
            // Dismiss paywall
        }
    }
}
```

### Purchase States

| Result | User Sees | Action |
|--------|-----------|--------|
| `.success` | Celebration animation | Set isPlus = true, dismiss |
| `.userCancelled` | Nothing | Clear any errors |
| `.pending` | "Pending approval" message | Wait for parent/admin |
| Verification failure | Error message | Suggest contact support |
| Network error | Retry prompt | Offer retry button |

### Error Handling

```swift
switch error {
case StoreKitError.networkError:
    purchaseError = "Network error. Check connection and try again."
case StoreKitError.userCancelled:
    purchaseError = nil  // Intentional, no error
case StoreKitError.notAvailableInStorefront:
    purchaseError = "Not available in your region."
default:
    purchaseError = "Purchase failed: \(error.localizedDescription)"
}
```

---

## Subscription Status Checking

### Current Implementation

```swift
func checkSubscriptionStatus() async {
    var hasActiveSubscription = false

    // Check monthly product status
    if let monthlyProduct = monthlyProduct {
        if let status = try? await monthlyProduct.subscription?.status {
            for statusItem in status {
                if case .verified(let renewal) = statusItem.renewalInfo,
                   case .verified(let transaction) = statusItem.transaction {
                    if renewal.currentProductID == monthlyID
                       && transaction.revocationDate == nil {
                        hasActiveSubscription = true
                        break
                    }
                }
            }
        }
    }

    // Repeat for annual product
    // ...

    isPlus = hasActiveSubscription
}
```

### Status Edge Cases

| Scenario | isPlus | Notes |
|----------|--------|-------|
| Active subscription | true | Normal state |
| Grace period | true | Payment retry in progress |
| Billing retry | true | Still entitled during retry |
| Expired | false | After grace period ends |
| Refunded | false | revocationDate is set |
| Upgraded mid-cycle | true | Immediate access to higher tier |
| Downgraded | true | Current tier until renewal |

---

## Usage Tracking

### Conversation Counting

```swift
// Storage keys
"conversationsUsed"    // Int: current month usage
"lastConversationDate" // Date: last conversation timestamp
"lastResetDate"        // Date: when count was last reset
"gandalfMode"          // Bool: debug bypass

// Check if can start
func canStartConversation() -> Bool {
    if UserDefaults.standard.bool(forKey: "gandalfMode") {
        return true  // Debug bypass
    }
    return isPlus || conversationsUsed < 8  // Note: Should be 2
}

// Record usage
func recordConversation() {
    guard !isPlus else { return }
    conversationsUsed += 1
    UserDefaults.standard.set(conversationsUsed, forKey: "conversationsUsed")
}

// Monthly reset
func resetMonthlyCount() {
    conversationsUsed = 0
    UserDefaults.standard.set(0, forKey: "conversationsUsed")
    UserDefaults.standard.set(Date(), forKey: "lastResetDate")
}
```

### Reset Logic

```swift
// On app launch, check if new month
if let lastReset = UserDefaults.standard.object(forKey: "lastResetDate") as? Date {
    let calendar = Calendar.current
    if !calendar.isDate(lastReset, equalTo: Date(), toGranularity: .month) {
        resetMonthlyCount()
    }
}
```

---

## Transaction Listener

### Background Updates

```swift
private func listenForTransactions() -> Task<Void, Error> {
    return Task.detached {
        for await result in StoreKit.Transaction.updates {
            do {
                let transaction = try self.checkVerified(result)
                await self.checkSubscriptionStatus()
                await transaction.finish()
            } catch {
                // Log but don't crash
                // Finish transaction anyway to prevent re-delivery
                await transaction?.finish()
            }
        }
    }
}
```

### Events Handled

| Event | Handler Action |
|-------|----------------|
| Renewal | checkSubscriptionStatus() → isPlus = true |
| Expiration | checkSubscriptionStatus() → isPlus = false |
| Refund | revocationDate set → isPlus = false |
| Upgrade | Immediate entitlement update |
| Downgrade | Scheduled for next period |

---

## Restore Purchases

```swift
func restorePurchases() async {
    isLoading = true

    do {
        try await AppStore.sync()  // Sync with App Store
        await checkSubscriptionStatus()

        if isPlus {
            // Show success
        } else {
            purchaseError = "No active subscriptions found."
        }
    } catch {
        purchaseError = "Unable to restore. Check connection."
    }

    isLoading = false
}
```

---

## Testing

### Sandbox Testing

1. **Create sandbox tester** in App Store Connect
2. **Sign out** of App Store on device
3. **Don't sign in** until purchase prompt
4. Subscriptions renew quickly in sandbox:
   - 1 month → 5 minutes
   - 1 year → 1 hour

### StoreKit Configuration File

Create `Configuration.storekit` for local testing:

```xml
<products>
    <product
        id="com.epilogue.plus.monthly"
        type="auto-renewable"
        price="7.99"
        subscription-duration="P1M"/>
    <product
        id="com.epilogue.plus.annual"
        type="auto-renewable"
        price="67.00"
        subscription-duration="P1Y"/>
</products>
```

### Debug Mode (Gandalf Mode)

```swift
// Enable unlimited conversations for testing
UserDefaults.standard.set(true, forKey: "gandalfMode")

// Check in code
if UserDefaults.standard.bool(forKey: "gandalfMode") {
    // Bypass all limits
}
```

---

## App Store Review Guidelines

### Required Elements

1. **Restore Purchases button** - ✅ Implemented in paywall
2. **Clear pricing display** - ✅ Shows $7.99/mo, $67/yr
3. **Terms of Use link** - ✅ Links to readepilogue.com/terms
4. **Privacy Policy link** - ✅ Links to readepilogue.com/privacy
5. **Cancellation info** - ✅ "Cancel anytime in Settings"
6. **Auto-renewal disclosure** - ⚠️ Add explicit renewal terms

### Recommended Disclosure Text

Add to paywall footer:

```
"Payment will be charged to your Apple ID account at confirmation
of purchase. Subscription automatically renews unless cancelled at
least 24 hours before the end of the current period. Your account
will be charged for renewal within 24 hours prior to the end of
the current period. You can manage and cancel your subscriptions
by going to your account settings on the App Store after purchase."
```

---

## Future Enhancements

### 1. Free Trial Implementation

```swift
// Add trial product
private let trialID = "com.epilogue.plus.trial"

// Check trial eligibility
func isEligibleForTrial() async -> Bool {
    guard let product = trialProduct else { return false }
    return await product.subscription?.isEligibleForIntroOffer ?? false
}
```

### 2. Promotional Offers

```swift
// For lapsed subscribers
func generatePromoOffer() async -> Product.SubscriptionOffer? {
    // Requires server-side signature generation
}
```

### 3. Offer Codes

- Create in App Store Connect
- Redeem via `SKPaymentQueue.presentCodeRedemptionSheet()`

### 4. Server-Side Receipt Validation

For enhanced security:

```swift
// Send receipt to your server
let receiptData = Bundle.main.appStoreReceiptURL
// POST to your validation endpoint
// Server verifies with Apple
```

---

## Metrics to Track

| Metric | Where to Track |
|--------|----------------|
| Paywall impressions | Analytics |
| Conversion rate | Downloads → Paid |
| Trial starts | StoreKit |
| Trial → Paid conversion | StoreKit |
| Monthly churn | StoreKit / App Store Connect |
| Annual churn | StoreKit / App Store Connect |
| MRR | App Store Connect |
| ARPU | Revenue / Active users |

---

## Troubleshooting

### Products Not Loading

```swift
// Retry with exponential backoff
var retryCount = 0
let maxRetries = 3

while retryCount < maxRetries {
    do {
        let products = try await Product.products(for: [monthlyID, annualID])
        // Success
    } catch {
        retryCount += 1
        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000)
    }
}
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Products empty | Not configured in ASC | Check product IDs, agreements |
| Purchase fails | Sandbox not signed in | Sign in when prompted |
| Status always false | Wrong product ID check | Verify ID matching |
| Transactions not finishing | Missing finish() call | Always call finish() |

---

## Code Locations

| Component | File |
|-----------|------|
| StoreKit Manager | `Managers/SimplifiedStoreKitManager.swift` |
| Paywall View | `Views/Premium/PremiumPaywallView.swift` |
| Usage check | `canStartConversation()` in StoreKit Manager |
| Record usage | `recordConversation()` in StoreKit Manager |
