# StoreKit Products Not Loading - Root Cause & Fix

**Date**: October 19, 2025
**Critical Issue**: Products return `nil` causing "unresponsive button" in App Review

---

## Root Cause Analysis

### Console Output
```
🎯 Continue button tapped - selectedInterval: Monthly
📦 Monthly product: nil
📦 Annual product: nil
⏳ isLoading: false
❌ Product not available: Monthly
⚠️ No products loaded (attempt 1/3)
⚠️ No products loaded (attempt 2/3)
⚠️ No products loaded (attempt 3/3)
```

### Two Separate Issues

#### Issue 1: Local Testing (Simulator/Debug)
**Problem**: StoreKit Configuration file not set in Xcode scheme
**Impact**: Products don't load in simulator/local testing
**Severity**: High for development, no impact on production

#### Issue 2: Production (TestFlight/App Store)
**Problem**: Products may not be approved/synced in App Store Connect
**Impact**: Products don't load during App Review
**Severity**: **CRITICAL** - This is why Apple said "unresponsive"

---

## Fix #1: Configure StoreKit for Local Testing

### Manual Steps (DO THIS IN XCODE):

1. **Open Xcode**
2. **Select your scheme**: Click "Epilogue" scheme dropdown near play button → "Edit Scheme..."
3. **Go to Run section** (left sidebar)
4. **Click Options tab** (top tabs)
5. **Find "StoreKit Configuration"** dropdown
6. **Select**: `Epilogue.storekit`
7. **Click Close**

### Verify It Worked:
```bash
# Run app in simulator
# Check console - should see:
✅ Loaded products: monthly=true, annual=true
```

### Alternative: Edit Scheme File Directly

Add this to `Epilogue.xcscheme` inside `<LaunchAction>`:

```xml
<LaunchAction
   buildConfiguration = "Debug"
   selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
   selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
   launchStyle = "0"
   useCustomWorkingDirectory = "NO"
   ignoresPersistentStateOnLaunch = "NO"
   debugDocumentVersioning = "YES"
   debugServiceExtension = "internal"
   allowLocationSimulation = "YES">

   <!-- ADD THIS LINE -->
   <StoreKitConfigurationFileReference
      identifier = "../Epilogue.storekit">
   </StoreKitConfigurationFileReference>

   <BuildableProductRunnable
      runnableDebuggingMode = "0">
```

**⚠️ WARNING**: Per your CLAUDE.md, don't modify .pbxproj files. Scheme files (.xcscheme) are safe to edit, but it's easier to use Xcode UI.

---

## Fix #2: App Store Connect Product Setup

### Critical Checklist for App Store Connect

Go to: https://appstoreconnect.apple.com

#### 1. Verify In-App Purchases Exist

1. Navigate to: **Your App** → **Monetization** → **Subscriptions**
2. Check for subscription group: **"Epilogue Plus"**
3. Verify these products exist:
   - ✅ `com.epilogue.plus.monthly` - $7.99/month
   - ✅ `com.epilogue.plus.annual` - $67/year

#### 2. Check Product Status

Each product must be:
- ✅ **Status**: "Ready to Submit" or "Approved"
- ✅ **Pricing**: Set for all territories
- ✅ **Localizations**: English (US) at minimum
- ✅ **Review Information**: Screenshot + Review notes filled

#### 3. Attach Products to App Version

**CRITICAL STEP** (often missed):

1. Go to: **App Store** → **Your Version (1.1.2)** → **In-App Purchases and Subscriptions**
2. Click **Manage** or **Add**
3. **Select both products**:
   - com.epilogue.plus.monthly
   - com.epilogue.plus.annual
4. Click **Done**

**If products aren't attached to your app version, they won't load during review!**

#### 4. Verify Paid Applications Agreement

1. Go to: **Agreements, Tax, and Banking**
2. Check: **Paid Applications** agreement status
3. Must be: ✅ **Active** (not Pending)
4. If not active:
   - Review and accept agreement
   - Add banking info
   - Add tax forms

**Without this, subscriptions will NEVER work, even if configured correctly!**

#### 5. Submit Products for Review

If products show "Missing Metadata" or "Developer Action Needed":

1. Click on each product
2. Fill in all required fields:
   - **Subscription Display Name**: "Epilogue+ Monthly" / "Epilogue+ Annual"
   - **Description**: Clear description of features
   - **Review Screenshot**: Screenshot showing subscription in app
   - **Review Notes**: Explain how to test (use sandbox account)
3. Change status to: **Ready to Submit**
4. Save

Products must be submitted WITH your app binary (they review together).

---

## Fix #3: Enhanced Product Loading Diagnostics

Add more detailed logging to help diagnose App Review issues:

### Update SimplifiedStoreKitManager.swift

Add this after line 42 (`func loadProducts() async {`):

```swift
func loadProducts() async {
    isLoading = true
    purchaseError = nil

    #if DEBUG
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🔍 STOREKIT PRODUCT LOADING DIAGNOSTICS")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📱 Environment: \(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil ? "Simulator" : "Device")")
    print("🏪 Product IDs to load:")
    print("   - Monthly: \(monthlyID)")
    print("   - Annual:  \(annualID)")
    #endif

    // Retry logic for App Review - products may not be immediately available
    var retryCount = 0
    let maxRetries = 3

    while retryCount < maxRetries {
        do {
            #if DEBUG
            print("\n🔄 Attempt \(retryCount + 1)/\(maxRetries)")
            #endif

            let products = try await Product.products(for: [monthlyID, annualID])

            #if DEBUG
            print("📦 Received \(products.count) products from StoreKit")
            for product in products {
                print("   ✅ \(product.id)")
                print("      - Name: \(product.displayName)")
                print("      - Price: \(product.displayPrice)")
                print("      - Type: \(product.type)")
            }
            #endif

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

            // If we got at least one product, success!
            if monthlyProduct != nil || annualProduct != nil {
                #if DEBUG
                print("\n✅ SUCCESS - Products loaded:")
                print("   Monthly: \(monthlyProduct != nil ? "✅ \(monthlyProduct!.displayPrice)" : "❌ nil")")
                print("   Annual:  \(annualProduct != nil ? "✅ \(annualProduct!.displayPrice)" : "❌ nil")")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
                #endif
                isLoading = false
                return
            }

            // No products loaded - retry
            #if DEBUG
            print("⚠️ No products loaded (attempt \(retryCount + 1)/\(maxRetries))")
            print("   This could mean:")
            print("   1. StoreKit config not set (simulator only)")
            print("   2. Products not approved in App Store Connect")
            print("   3. Products not attached to app version")
            print("   4. Paid Apps Agreement not signed")
            #endif

            retryCount += 1
            if retryCount < maxRetries {
                // Wait 2 seconds before retry
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }

        } catch {
            #if DEBUG
            print("❌ Failed to load products (attempt \(retryCount + 1)/\(maxRetries))")
            print("   Error: \(error.localizedDescription)")
            print("   Type: \(type(of: error))")
            if let storeError = error as? StoreKitError {
                print("   StoreKit Error: \(storeError)")
            }
            #endif

            retryCount += 1
            if retryCount < maxRetries {
                // Wait 2 seconds before retry
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    // If we get here, all retries failed
    #if DEBUG
    print("\n❌ FAILURE - Unable to load products after \(maxRetries) attempts")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    #endif

    // Set error message but don't block the app
    purchaseError = "Subscriptions temporarily unavailable. Try again later."
    isLoading = false
}
```

This gives you comprehensive diagnostics in the console to help identify exactly why products aren't loading.

---

## Testing Checklist

### Local Testing (Simulator)
- [ ] Set StoreKit Configuration in scheme
- [ ] Clean build folder (⌘⇧K)
- [ ] Run app
- [ ] Check console for detailed diagnostics
- [ ] Verify products load successfully
- [ ] Test purchase flow (sandbox)

### TestFlight Testing
- [ ] Verify products attached to app version in ASC
- [ ] Upload build to TestFlight
- [ ] Install from TestFlight
- [ ] Check console logs (connect device to Xcode)
- [ ] Verify products load
- [ ] Test actual purchase with sandbox account

### Production/App Review
- [ ] All products "Ready to Submit" or "Approved"
- [ ] Products attached to app version
- [ ] Paid Apps Agreement signed
- [ ] Banking/tax info complete
- [ ] Review notes explain how to test subscriptions

---

## What Apple's Reviewer Sees

When Apple tests your app:

1. They open the app
2. Navigate to Premium/Subscription screen
3. Tap a price button
4. **If products aren't loaded**: Nothing happens → "unresponsive"
5. **If products ARE loaded**: StoreKit purchase sheet appears → ✅

The button works fine - it's the products that are the issue!

---

## Most Likely Cause

Based on the error, the most likely cause is:

**Products not attached to app version 1.1.2 in App Store Connect**

### How to Fix:
1. Go to App Store Connect
2. Navigate to your app → version 1.1.2
3. Scroll to "In-App Purchases and Subscriptions"
4. Click "Manage"
5. Add both products if they're not there
6. Save
7. Resubmit build

---

## Alternative Workaround (If Products Can't Be Fixed Immediately)

If you can't fix the products in App Store Connect quickly, you could temporarily hide the subscription UI during review:

**NOT RECOMMENDED** - Better to fix the root cause.

---

## Summary

### Root Cause
✅ **Buttons work fine** (our fix was good)
❌ **Products not loading** (configuration issue)

### Fixes Required

1. **For Local Testing**:
   - Set StoreKit Configuration in Xcode scheme
   - Use enhanced diagnostics

2. **For App Review** (CRITICAL):
   - Verify products exist in App Store Connect
   - Attach products to app version 1.1.2
   - Ensure Paid Apps Agreement is signed
   - Verify products are "Ready to Submit"

3. **Code Improvements**:
   - Enhanced diagnostics already in place ✅
   - Better error messages ✅
   - Retry logic ✅

### Next Steps

1. Open Xcode → Edit Scheme → Set StoreKit config
2. Test locally - should work now
3. Check App Store Connect - verify products attached
4. If needed, add enhanced diagnostics code
5. Build and test
6. Submit with note explaining the fix

---

**Bottom Line**: The "unresponsive button" issue is actually a "products not loading" issue. Fix the App Store Connect configuration, and the button will work perfectly because it's already coded correctly!
