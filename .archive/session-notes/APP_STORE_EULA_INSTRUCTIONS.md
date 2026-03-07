# App Store Connect - EULA Implementation Instructions

**Date**: October 19, 2025
**Issue**: Apple Review Rejection - Missing EULA Link for Auto-Renewable Subscriptions

---

## What Apple Requires

Apps offering auto-renewable subscriptions must include:

1. **In the app binary**:
   - Title of auto-renewing subscription ✅ (Already included)
   - Length of subscription ✅ (Already included)
   - Price of subscription ✅ (Already included)
   - Functional links to Privacy Policy ✅ (Already included)
   - Functional links to Terms of Use (EULA) ❌ **MISSING**

2. **In App Store Connect metadata**:
   - Functional link to Privacy Policy in Privacy Policy field ✅ (Already included)
   - Functional link to Terms of Use (EULA) in either:
     - App Description field, OR
     - EULA field ❌ **MISSING**

---

## Step 1: Upload Documents to Website

Upload these files to your website at `https://readepilogue.com`:

1. **Privacy Policy**: `PRIVACY_POLICY.md` → `https://readepilogue.com/privacy`
2. **Terms of Use**: `TERMS_OF_USE.md` → `https://readepilogue.com/terms`

**Important**: These URLs MUST be accessible without authentication and load quickly.

---

## Step 2: Update App Store Connect Metadata

### Option A: Add EULA Link to App Description (Recommended)

In App Store Connect, update your App Description to include:

```
[Your existing app description text...]

Privacy Policy: https://readepilogue.com/privacy
Terms of Use: https://readepilogue.com/terms
```

**Example placement** (at the bottom of description):

```
PRIVACY & LEGAL

Read our Privacy Policy: https://readepilogue.com/privacy
Review our Terms of Use: https://readepilogue.com/terms

Epilogue+ subscriptions are auto-renewing and can be managed or cancelled anytime in iOS Settings.
```

### Option B: Add Custom EULA in App Store Connect

Alternatively, in App Store Connect:

1. Go to your app → **App Information** → **App Store** section
2. Find **License Agreement** section
3. Select **Custom EULA**
4. Paste the entire contents of `TERMS_OF_USE.md`

---

## Step 3: Update In-App Links (Code Changes Required)

You'll need to add Terms of Use links in the app where subscriptions are displayed.

### Location 1: PremiumPaywallView Footer

**Current code** (line ~407):
```swift
private var footerSection: some View {
    VStack(spacing: 8) {
        Text("Cancel anytime in Settings")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
    }
    .opacity(ctaAppeared ? 1 : 0)
}
```

**Updated code**:
```swift
private var footerSection: some View {
    VStack(spacing: 8) {
        Text("Cancel anytime in Settings")
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.listItemPadding)

        // EULA and Privacy links
        HStack(spacing: 16) {
            Link("Privacy Policy", destination: URL(string: "https://readepilogue.com/privacy")!)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))

            Text("•")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))

            Link("Terms of Use", destination: URL(string: "https://readepilogue.com/terms")!)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 4)
    }
    .opacity(ctaAppeared ? 1 : 0)
}
```

### Location 2: Settings View (Recommended)

Add a "Legal" section in SettingsView with links to:
- Privacy Policy
- Terms of Use
- Licenses (if applicable)

---

## Step 4: Update APP_STORE_REVIEW_NOTES.md

Update the links in your review notes:

**Old**:
```markdown
- **Privacy Policy**: https://krispuckett.craft.me/BcGmXbnrNCvSGp
- **Terms of Service**: https://krispuckett.craft.me/clvC7VnuiypGo1
```

**New**:
```markdown
- **Privacy Policy**: https://readepilogue.com/privacy
- **Terms of Use**: https://readepilogue.com/terms
```

---

## Step 5: Testing Checklist

Before resubmitting:

- [ ] Upload both documents to website
- [ ] Verify URLs work in Safari (no auth required)
- [ ] Verify URLs work on mobile Safari
- [ ] Update App Description in App Store Connect
- [ ] Add in-app links to PremiumPaywallView
- [ ] Test links in app on physical device
- [ ] Update APP_STORE_REVIEW_NOTES.md
- [ ] Build new version (increment build number)
- [ ] Submit with response to Apple's feedback

---

## Sample Response to Apple Review Team

When resubmitting, include this note:

```
Hello,

Thank you for the feedback. I have addressed both issues:

1. **Unresponsive Button on iPad Pro**: Fixed hit testing and added proper error handling
   for the subscription purchase flow. Added debug logging and retry logic for StoreKit
   product loading.

2. **Missing EULA Link**: Added functional Terms of Use link to:
   - App Description: https://readepilogue.com/terms
   - In-app footer on subscription screen
   - Settings screen under Legal section

Both the Privacy Policy (https://readepilogue.com/privacy) and Terms of Use are now
properly linked throughout the app and in App Store Connect metadata.

Please let me know if you need any additional information.

Best regards,
Kris
```

---

## Additional Notes

### Subscription Info Already Included in App ✅

Your PremiumPaywallView already includes:

- ✅ Subscription title: "EPILOGUE+" (line 154)
- ✅ Billing intervals: Monthly/Annual with pricing (lines 204-218)
- ✅ Price display: "$7.99/mo" and "$67/yr" (lines 204, 207)
- ✅ Feature list: Clear description of benefits (lines 165-169)
- ✅ Cancellation info: "Cancel anytime in Settings" (line 407)

You just need to add the EULA link!

### Apple's Guideline Reference

- **Guideline 3.1.2**: Business - Payments - Subscriptions
- Requires: "Functional links to the privacy policy and Terms of Use (EULA)"
- Must appear in: App binary AND App Store Connect metadata

---

## Quick Fix Summary

**Minimum required to pass review**:

1. Upload `TERMS_OF_USE.md` to `https://readepilogue.com/terms`
2. Add this line to your App Description in App Store Connect:
   ```
   Terms of Use: https://readepilogue.com/terms
   ```
3. Add EULA link to PremiumPaywallView footer (code change above)
4. Build and resubmit

That's it!

---

**Files Created**:
- ✅ `/Users/kris/Epilogue/TERMS_OF_USE.md` - Complete EULA document
- ✅ `/Users/kris/Epilogue/PRIVACY_POLICY.md` - Already exists
- ✅ This instruction file

**Next Steps**: Upload documents to website, update App Store Connect, add in-app links, resubmit.
