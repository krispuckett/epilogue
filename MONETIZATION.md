# Epilogue Monetization Strategy

> Last updated: December 2024

## Executive Summary

Epilogue is positioned at the intersection of **reading companion apps** (StoryGraph, Goodreads, Bookly) and **AI assistants** (ChatGPT, Perplexity). This unique positioning justifies premium pricing for AI features while maintaining competitive pricing for the book tracking category.

**Current Implementation:**
- **Free tier:** 2 ambient AI conversations/month
- **Epilogue+:** $7.99/month or $67/year (30% savings)

**Recommendation:** The current pricing is well-positioned. Minor adjustments to feature gating and trial strategy can optimize conversion.

---

## Market Research

### Reading & Book Tracking Apps

| App | Monthly | Annual | Key Features |
|-----|---------|--------|--------------|
| **StoryGraph** | $4.99 | ~$50 | Charts, stats, no ads |
| **Bookly** | $8.99 | ~$90 | Reading timer, analytics |
| **Bookmory** | $3.49 | $30.99 | Reading tracker |
| **Readwise** | $9.99-$12.99 | ~$120 | Highlights, Reader app |
| **Oku** | TBD | TBD | Social, collections |

**Insight:** Reading apps range $3.49-$12.99/month. Epilogue at $7.99 sits in the upper-middle, justified by AI features that no competitor offers.

### AI Assistant Apps

| App | Monthly | Annual | Key Features |
|-----|---------|--------|--------------|
| **ChatGPT Plus** | $20 | ~$200 | GPT-4o, DALL-E, voice |
| **Perplexity Pro** | $20 | $200 | Web search, unlimited |
| **Claude Pro** | $20 | ~$200 | Extended context |
| **Perplexity Max** | $200 | $2,000 | Enterprise features |

**Insight:** Standalone AI subscriptions are $20/month. Epilogue's AI is deeply integrated into a reading workflow, not a general-purpose assistant. This justifies a lower price point while maintaining premium value.

### iOS Subscription Benchmarks

| Metric | Benchmark |
|--------|-----------|
| Industry standard monthly | $4.99-$9.99 |
| Industry standard annual | $29.99-$99.99 |
| iOS vs Android spending | iOS users spend 2.5x more |
| Subscription share of revenue | 96% of App Store spending |

**Sources:**
- [RevenueCat State of Subscription Apps 2025](https://www.revenuecat.com/state-of-subscription-apps-2025/)
- [Adapty App Pricing Strategies](https://adapty.io/blog/how-to-price-mobile-in-app-subscriptions/)
- [Perplexity Pricing](https://juma.ai/blog/perplexity-pricing)

---

## Tier Structure

### Free Tier
*"Taste the magic, feel the limit"*

**Included:**
| Feature | Limit |
|---------|-------|
| Library management | Unlimited books |
| Manual quotes & notes | Unlimited |
| Goodreads import | One-time |
| Reading progress tracking | Full access |
| Search (library, notes, quotes) | Full access |
| Markdown export | Full access |
| Readwise sync | Full access |
| Home screen widgets | Full access |
| Siri Shortcuts | Full access |
| iCloud sync | Full access |
| **Ambient AI conversations** | **2/month** |

**Excluded (Paywall):**
- Unlimited ambient AI conversations
- AI session summaries
- AI book recommendations
- Camera OCR quote capture (potential future gate)

**Rationale:** The free tier is generous for core book management, creating sticky users. The AI limit creates a compelling upgrade trigger when users experience the value of ambient mode.

---

### Epilogue+ (Pro Tier)
*"Your reading companion, unlimited"*

**Price:** $7.99/month or $67/year (30% savings)

**Everything in Free, plus:**
| Feature | Value |
|---------|-------|
| Unlimited ambient AI conversations | Core value prop |
| Advanced AI models | Premium quality |
| AI session summaries | Automatic insights |
| AI book recommendations | Personalized discovery |
| On-device processing (iOS 26+) | Privacy + speed |
| Priority support | Future benefit |

**Why This Price:**
1. **Above reading apps** ($4.99) - justified by AI features
2. **Below AI apps** ($20) - we're specialized, not general-purpose
3. **30% annual discount** - industry standard, drives commitment
4. **$5.58/mo effective annual** - psychological win under $6

---

### Future: Epilogue Pro (Optional Higher Tier)
*Consider only if usage patterns justify*

**Potential Price:** $14.99/month or $119/year

**Would Include:**
- Family sharing (5 accounts)
- Extended conversation history
- Export to Notion/Obsidian with AI summaries
- Beta feature access

**Launch Criteria:**
- 1,000+ Plus subscribers
- Clear demand signal from power users
- At least 3 differentiating features ready

---

## Feature Gating Strategy

### Gating Philosophy

```
┌─────────────────────────────────────────────────────────────┐
│                      ALWAYS FREE                             │
│  (Build habit, create investment, drive word-of-mouth)      │
├─────────────────────────────────────────────────────────────┤
│  • Library management        • Markdown export              │
│  • Manual notes/quotes       • Readwise sync                │
│  • Goodreads import          • Widgets & Shortcuts          │
│  • Reading progress          • iCloud sync                  │
│  • Full search               • Basic theme detection        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      METERED FREE                            │
│  (Experience value, hit limit, convert)                     │
├─────────────────────────────────────────────────────────────┤
│  • Ambient AI conversations  → 2/month free                 │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      PLUS EXCLUSIVE                          │
│  (Clear premium value, drives conversion)                   │
├─────────────────────────────────────────────────────────────┤
│  • Unlimited ambient mode    • AI session summaries         │
│  • AI book recommendations   • Advanced AI models           │
│  • On-device processing      • (Future: OCR capture)        │
└─────────────────────────────────────────────────────────────┘
```

### Feature-by-Feature Breakdown

| Feature | Free | Plus | Rationale |
|---------|------|------|-----------|
| **Library management** | ✅ Unlimited | ✅ | Core value, drives investment |
| **Quote capture (manual)** | ✅ Unlimited | ✅ | Core workflow, no API cost |
| **Quote capture (OCR)** | ✅ | ✅ | On-device, no API cost |
| **Quote card export** | ✅ | ✅ | Viral loop, share-worthy |
| **AI chat (ambient)** | 2/mo | ✅ Unlimited | API cost, premium value |
| **AI session summaries** | ❌ | ✅ | API cost, premium value |
| **AI recommendations** | ❌ | ✅ | API cost, premium value |
| **Ambient voice mode** | 2/mo | ✅ Unlimited | Same as ambient limit |
| **Theme detection** | ✅ Basic | ✅ Enhanced | On-device, no cost |
| **Reading analytics** | ✅ | ✅ | On-device, drives engagement |
| **Readwise sync** | ✅ | ✅ | User's own API, no cost to us |

### Conversation Limit Logic

Current implementation in `SimplifiedStoreKitManager.swift:337-349`:

```swift
func conversationsRemaining() -> Int? {
    // Gandalf mode = unlimited (debug)
    if UserDefaults.standard.bool(forKey: "gandalfMode") {
        return nil
    }
    guard !isPlus else { return nil }
    return max(0, 8 - conversationsUsed)  // Note: UI shows 2, code shows 8
}
```

**Recommendation:** Align code limit with UI. Set to **2 conversations/month** for free tier.

---

## Paywall Strategy

### Paywall Placement (Soft Paywall)

**Trigger Points:**
1. **Limit reached** - After 2nd free conversation, show paywall
2. **Try to start 3rd conversation** - Intercept with paywall
3. **Settings > Epilogue+** - Deliberate exploration
4. **AI feature discovery** - When browsing Plus-only features

**Never Block:**
- Library access
- Existing notes/quotes
- Reading progress
- Export functionality
- Widget functionality

### Paywall UI (Already Implemented)

Location: `Views/Premium/PremiumPaywallView.swift`

**Current Flow:**
1. Animated orb header (Metal shader)
2. Usage status ("2 of 2 conversations used")
3. Feature comparison (Plus vs Free)
4. Billing interval picker (Annual default)
5. Continue CTA
6. Success celebration with confetti

**Optimization Opportunities:**
- [ ] Default to annual selection (already implemented ✅)
- [ ] Show monthly-equivalent price for annual
- [ ] Add social proof ("Join 1,000+ readers")
- [ ] Add testimonials when available

---

## Trial Period Strategy

### Recommendation: 7-Day Free Trial

**Implementation:**
```
Product ID: com.epilogue.plus.trial
Duration: 7 days
Auto-renews to: com.epilogue.plus.monthly OR .annual (user choice)
```

**Why 7 Days:**
- Industry data shows 7 days optimal for monthly subscriptions
- Long enough to experience ambient mode multiple times
- Short enough to maintain urgency
- 5-9 days is the trending sweet spot (52% of apps)

### Trial Conversion Optimization

| Tactic | Expected Impact |
|--------|-----------------|
| Collect payment upfront | 5x better conversion |
| Day 1: Welcome + tutorial | Activation |
| Day 3: Feature highlight push | Engagement |
| Day 5: "Trial ending soon" | Urgency |
| Day 6: Final value reminder | Last chance |

**Conversion Benchmarks:**
- Free trial → Paid: 8-12% is good, 15-25% is great
- Industry median Day 35 retention: 2.7%

---

## Family Sharing Considerations

### Current: Not Supported

**Rationale:**
- AI API costs are per-user
- Single subscription can't cover family API usage
- Early-stage product, simpler model

### Future: Family Plan Option

If demand exists, consider:
- **Family plan:** $12.99/month for up to 5 accounts
- Requires server-side usage tracking per family member
- Consider separate family tier, not Family Sharing

---

## Pricing Psychology

### Annual vs Monthly Framing

**Current:**
- Monthly: $7.99/month
- Annual: $67/year (30% savings)
- Annual equivalent: $5.58/month

**Display Strategy:**
```
Annual: "$5.58/mo" (billed as $67/yr)  ← Default selection
Monthly: "$7.99/mo"
```

**Anchoring:** Show annual first, make it the obvious choice.

### Price Elasticity Considerations

| Segment | Price Sensitivity | Recommendation |
|---------|-------------------|----------------|
| Avid readers (10+ books/year) | Low | Current price works |
| Casual readers (3-5 books/year) | Medium | Free tier sufficient |
| Tech-savvy book lovers | Low | Will pay for AI |
| Students | High | Consider 50% discount |

---

## Revenue Projections

### Assumptions
- 10,000 downloads in Year 1
- 3% conversion rate (industry average for quality apps)
- 70% annual, 30% monthly split
- 15% monthly churn, 40% annual churn (industry benchmarks)

### Year 1 Projections

| Metric | Conservative | Optimistic |
|--------|--------------|------------|
| Downloads | 10,000 | 25,000 |
| Conversion rate | 2% | 5% |
| Paid subscribers | 200 | 1,250 |
| MRR (Month 12) | $1,200 | $7,500 |
| ARR | $14,400 | $90,000 |

### Break-Even Analysis

**API Costs per User:**
- Perplexity API: ~$0.01-0.05 per conversation
- 20 conversations/user/month = ~$0.20-1.00/month
- Margin at $7.99: ~$7/user (87%+ gross margin)

---

## Implementation Checklist

### Phase 1: Current State (Implemented ✅)
- [x] StoreKit 2 integration
- [x] Product IDs configured
- [x] Paywall UI with celebration
- [x] Conversation limit tracking
- [x] Monthly reset logic
- [x] Restore purchases
- [x] Transaction listener

### Phase 2: Optimization (Recommended)
- [ ] Align code limit (8) with UI limit (2)
- [ ] Add 7-day free trial option
- [ ] Implement trial onboarding sequence
- [ ] Add push notification reminders
- [ ] A/B test paywall copy

### Phase 3: Growth (Future)
- [ ] Add student discount (50%)
- [ ] Implement referral program
- [ ] Add promotional offers (first month $1)
- [ ] Consider family plan
- [ ] Add lifetime purchase option ($199)

---

## StoreKit Implementation Details

See: `docs/STOREKIT_IMPLEMENTATION.md` for technical specification.

---

## Appendix: Competitive Positioning

```
                    HIGH
                     │
        Epilogue+    │    ChatGPT Plus
        ($7.99)      │    Perplexity Pro
                     │    ($20)
    ─────────────────┼─────────────────────
     AI INTEGRATION  │  GENERAL PURPOSE
    ─────────────────┼─────────────────────
                     │
        Readwise     │    Notion AI
        ($9.99)      │    ($10)
                     │
                    LOW
     READING-FOCUSED        GENERAL PURPOSE
```

Epilogue occupies a unique position: **high AI integration** with **deep reading focus**. This justifies premium pricing above basic reading apps while remaining accessible compared to general AI tools.

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2024-12 | Set free limit to 2 conversations | Balance between taste and urgency |
| 2024-12 | Price at $7.99/month | Above reading apps, below AI apps |
| 2024-12 | 30% annual discount | Industry standard, drives commitment |
| 2024-12 | Keep OCR free | On-device, no API cost, drives quotes |
| 2024-12 | Keep Readwise sync free | User's own API, good will |
