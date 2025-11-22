# Generic Ambient Mode - V1 Implementation Roadmap

## Executive Summary

This document defines the **Minimum Viable Product (V1)** for Generic Ambient Mode and provides a detailed implementation roadmap.

**Goal:** Launch a focused, high-quality generic reading companion in 3-4 weeks that complements the existing book-specific ambient mode.

**Principle:** Ship something valuable quickly, learn from usage, iterate based on real user behavior.

---

## V1 Scope Definition

### ✅ IN SCOPE (Must Have)

#### Core Functionality
1. **Generic Conversation Mode**
   - Text and voice input (reuse existing infrastructure)
   - Persistent conversation thread (short-term memory only)
   - Reading-focused responses with boundary management

2. **Mode Switching**
   - Simple UI to switch between generic and book-specific modes
   - Conversation state preserved across switches
   - Clear visual distinction between modes

3. **Context-Aware Responses**
   - Book recommendations using existing recommendation engine
   - Reading habit insights using SessionIntelligence
   - Reflection on finished books
   - Library overview and organization help

4. **Boundary Management**
   - System prompt enforces reading-only topics
   - Polite redirects for off-topic requests
   - Suggestions to switch to book mode when appropriate

5. **Basic UI**
   - Amber gradient background (generic mode identity)
   - Mode selector component (dropdown or segmented control)
   - Existing chat interface (UnifiedChatView)
   - Mode indicator (always visible)

#### Technical Requirements
- GenericAmbientContextManager for context building
- UnifiedAmbientCoordinator for mode routing
- Thread-based conversation memory
- Intent detection (simple keyword-based)
- Generic system prompt

### ❌ OUT OF SCOPE (V1)

**Deferred to V2+:**
- Live Activities for generic mode
- Long-term conversation memory and search
- Siri shortcuts and voice triggers
- Advanced stats visualizations (charts, graphs)
- Goal setting and tracking
- Reading challenges
- Cross-session thematic exploration UI
- Social features (book clubs, sharing)
- Proactive conversation initiation
- Multiple concurrent conversation threads
- ML-based intent classification
- Persistent context caching

**Why defer:**
- Learn what users actually do in generic mode first
- Avoid over-engineering before validation
- Ship faster with focused feature set
- Reduce initial testing surface area

### 🤔 MAYBE (Decide During Development)

**Evaluate based on effort vs. value:**
- Home screen widget showing recent conversation
- Notification prompts for contextual moments (just finished book)
- Quick prompts / suggested questions UI
- Export conversation to notes
- Dark mode optimization for gradients

**Decision criteria:**
- Does it require >2 days of work? → Defer to V2
- Is it essential for V1 value prop? → Include
- Can we A/B test it post-launch? → Defer

---

## Success Metrics

### Usage Metrics
- **Adoption:** % of users who try generic mode (target: >40% in first month)
- **Retention:** % who return to generic mode >3 times (target: >60%)
- **Session length:** Average time per generic session (hypothesis: 3-7 minutes)
- **Messages per session:** (hypothesis: 4-8 messages)

### Quality Metrics
- **On-topic rate:** % of conversations that stay reading-focused (target: >90%)
- **Mode switching:** % of sessions that involve mode switches (hypothesis: 20-30%)
- **Recommendation acceptance:** % of book recs that get added to library (target: >30%)

### Technical Metrics
- **Response time:** <2 seconds for AI responses
- **Context size:** Average tokens per request (<4K target)
- **Error rate:** <1% failed AI calls
- **Mode switch time:** <500ms

### User Feedback
- **Survey question:** "How useful is generic ambient mode?" (1-5 scale, target: >4.0)
- **Qualitative:** What topics do users ask about most?
- **Feature requests:** What do users wish it could do?

---

## Implementation Roadmap

### Week 1: Foundation & Core Architecture

**Day 1-2: Models & Enums**
- [ ] Create `AmbientModeType` enum (2 hours)
  - File: `Epilogue/Models/AmbientMode.swift`
  - Cases: `.generic`, `.bookSpecific(bookID, page)`, `.inactive`
  - Thread ID computation
  - Unit tests

- [ ] Extend `ConversationMemory` for threads (4 hours)
  - File: `Epilogue/Services/Ambient/ConversationMemory.swift`
  - Add `MemoryEntry` SwiftData model
  - Implement `addMessage(threadID:content:isUser:)`
  - Implement `getRecentMessages(threadID:limit:)`
  - Unit tests for thread isolation

- [ ] Add generic system prompt (2 hours)
  - File: `Epilogue/Services/AICompanionService.swift` or new `SystemPrompts.swift`
  - Define prompt text
  - Add prompt selection logic based on mode

**Day 3-5: Context Manager**
- [ ] Create `GenericAmbientContextManager` (12 hours)
  - File: `Epilogue/Services/Ambient/GenericAmbientContextManager.swift`
  - Implement intent detection (keyword-based)
  - Build context builders:
    - `getCurrentReadingSnapshot()`
    - `getRecentlyFinished(limit:)`
    - `buildTasteContext()` - uses LibraryTasteAnalyzer
    - `buildPatternContext()` - uses SessionIntelligence
    - `buildBookDiscussionContext(bookTitle:)`
    - `buildLibraryOverview()`
  - Implement `buildContext(for:conversationHistory:)` main method
  - Unit tests for each context builder

**Deliverable:** Context manager can build rich, intent-based context for generic queries

**Risk:** SessionIntelligence may not have all needed methods
- **Mitigation:** Create wrapper methods or use existing LibraryService data

---

### Week 2: Coordinator & Mode Switching

**Day 1-3: Unified Coordinator**
- [ ] Create `UnifiedAmbientCoordinator` (12 hours)
  - File: `Epilogue/Navigation/UnifiedAmbientCoordinator.swift`
  - Implement mode state management
  - Implement `switchToGenericMode()`
  - Implement `switchToBookMode(book:currentPage:)`
  - Implement `sendMessage(_:)` with mode-based routing
  - Implement conversation loading/saving
  - Implement system prompt selection
  - Wire to existing `AICompanionService`

- [ ] Integration with existing views (4 hours)
  - Modify `ContentView` to use UnifiedAmbientCoordinator
  - Replace existing coordinator references
  - Test mode switching preserves state

**Day 4-5: UI Components**
- [ ] Create `AmbientModeSelector` component (6 hours)
  - File: `Epilogue/Views/Ambient/Components/AmbientModeSelector.swift`
  - Dropdown/expandable list showing mode options
  - Generic mode option
  - List of active reading books
  - Selection state management
  - Haptic feedback on switch
  - Unit tests for state management

- [ ] Create `GenericAmbientBackground` (2 hours)
  - File: `Epilogue/Views/Components/GenericAmbientBackground.swift`
  - Amber gradient (reuse EnhancedAmberGradient if possible)
  - Subtle breathing animation
  - No voice reactivity (keep simple)

**Deliverable:** Users can switch between generic and book modes with visual feedback

**Risk:** Mode switching may feel jarring or slow
- **Mitigation:** Add smooth gradient transitions, test on device for performance

---

### Week 3: Integration & Polish

**Day 1-2: AmbientModeView Integration**
- [ ] Modify `AmbientModeView` (8 hours)
  - File: `Epilogue/Views/Ambient/AmbientModeView.swift`
  - Add mode selector at top
  - Conditional background rendering (generic vs. book)
  - Wire coordinator to chat interface
  - Ensure voice input works in generic mode
  - Test conversation flow

- [ ] Mode indicator persistence (2 hours)
  - Always show current mode
  - Update as mode changes
  - Clear visual distinction

**Day 3-4: Testing**
- [ ] Unit tests (6 hours)
  - Context manager intent detection
  - Context builder output validation
  - Coordinator mode switching logic
  - Conversation memory thread isolation

- [ ] Integration tests (4 hours)
  - End-to-end conversation flow
  - Mode switching preserves state
  - AI responses are on-topic
  - Voice input in generic mode

- [ ] Manual QA (4 hours)
  - Test on real device with real library
  - Try all major use cases (recommendations, habits, reflection)
  - Test boundary management (off-topic queries)
  - Test mode switching during conversation
  - Check gradient animations
  - Verify voice recognition works

**Day 5: Bug Fixes & Polish**
- [ ] Address bugs from testing (6 hours)
- [ ] Performance optimization if needed (2 hours)
  - Measure context build time
  - Optimize slow queries
  - Reduce AI response latency

**Deliverable:** Stable, tested generic ambient mode ready for beta

**Risk:** Edge cases in conversation state management
- **Mitigation:** Extensive manual testing with various conversation flows

---

### Week 4: Beta Testing & Iteration

**Day 1: Beta Release Prep**
- [ ] Create onboarding for generic mode (3 hours)
  - Brief explanation of what generic mode is
  - Example prompts to try
  - Visual distinction from book mode
  - Skippable for existing users

- [ ] Analytics instrumentation (2 hours)
  - Log generic mode sessions
  - Track conversation topics
  - Track mode switches
  - Track off-topic redirects

- [ ] Beta release notes (1 hour)
  - Explain new feature
  - Highlight use cases
  - Ask for feedback

**Day 2-3: Beta Testing**
- [ ] Deploy to TestFlight (1 hour)
- [ ] Recruit 10-15 beta testers (existing engaged users)
- [ ] Monitor usage and feedback (ongoing)
- [ ] Daily check-ins with beta group

**Day 4-5: Iteration**
- [ ] Analyze usage data
  - What topics are users asking about?
  - Are they staying on-topic?
  - Are recommendations useful?
  - How long are sessions?

- [ ] Address critical feedback (8 hours)
  - Fix bugs
  - Adjust system prompt if needed
  - Improve context if responses feel generic
  - Polish UI based on feedback

**Deliverable:** Production-ready V1 informed by real usage

**Risk:** Users don't understand when to use generic vs. book mode
- **Mitigation:** Clear onboarding, contextual suggestions, iterate on messaging

---

## Launch Criteria

Generic Ambient Mode V1 is ready to ship when:

### Functionality ✅
- [ ] Users can start generic conversation from dedicated entry point
- [ ] Users can switch between generic and book-specific modes
- [ ] Conversation state persists across mode switches
- [ ] AI provides relevant, personalized responses for:
  - [ ] Book recommendations
  - [ ] Reading habit questions
  - [ ] Reflection on finished books
  - [ ] Library organization
- [ ] Off-topic requests are politely redirected
- [ ] Voice input works in generic mode

### Quality ✅
- [ ] No critical bugs
- [ ] AI response time <2 seconds (p95)
- [ ] On-topic rate >85% in beta testing
- [ ] Mode switch time <500ms
- [ ] No conversation state loss on mode switch

### User Experience ✅
- [ ] Clear visual distinction between generic and book modes
- [ ] Mode selector is intuitive (beta testers can use without instruction)
- [ ] At least 3 beta testers report it's "useful" or "very useful"
- [ ] Onboarding is clear and concise

### Technical ✅
- [ ] Unit tests pass (>80% coverage for new code)
- [ ] Integration tests pass
- [ ] No memory leaks
- [ ] Analytics tracking works
- [ ] Works on iOS 17+ (target OS versions)

---

## Post-Launch Plan

### Week 1-2 After Launch
- Monitor usage metrics daily
- Collect qualitative feedback
- Address any critical bugs within 24 hours
- Gather feature requests

### Month 1 Review
- Analyze success metrics vs. targets
- Identify top user pain points
- Prioritize V2 features based on real usage
- Decide: What should we build next?

### V2 Planning (Based on V1 Learnings)

**If users love generic mode:**
- Add long-term conversation memory
- Build thematic exploration UI
- Add goal setting and tracking
- Create Siri shortcuts
- Build advanced stats visualizations

**If adoption is low:**
- Investigate why (lack of discovery? unclear value?)
- Improve onboarding
- Add contextual entry points
- Simplify mode switching

**If usage is high but quality is low:**
- Improve context building (more relevant data)
- Enhance system prompt (better boundary management)
- Add ML-based intent classification
- Personalize response style

---

## Resource Requirements

### Development Time
- **Total:** 3-4 weeks (single developer, full-time)
- **Breakdown:**
  - Week 1: Foundation (20 hours)
  - Week 2: Coordinator & UI (24 hours)
  - Week 3: Integration & Testing (24 hours)
  - Week 4: Beta & Iteration (16 hours)
- **Total:** ~84 hours

### Skills Required
- SwiftUI (intermediate to advanced)
- SwiftData (intermediate)
- AI integration (existing experience with AICompanionService)
- Testing (unit, integration, manual QA)

### External Dependencies
- Existing infrastructure (LibraryService, SessionIntelligence, etc.)
- AI provider (Claude/GPT-4o via AICompanionService)
- TestFlight for beta distribution

### Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| SessionIntelligence missing needed methods | Medium | Medium | Use LibraryService directly or create adapter |
| AI responses feel generic | High | Medium | Iterate on system prompt and context quality |
| Users confused about mode distinction | Medium | High | Clear onboarding, visual cues, contextual help |
| Performance issues with context building | Medium | Low | Implement caching, optimize queries |
| Beta testers don't engage | Low | Medium | Recruit enthusiastic users, provide clear prompts |

---

## Alternative Approaches Considered

### Approach 1: Separate App Section (Rejected)
**Idea:** Generic mode as separate tab, not integrated with book mode

**Pros:**
- Clearer separation
- No mode switching complexity

**Cons:**
- Duplicated UI code
- Users might not discover it
- Can't easily reference book context

**Verdict:** Rejected - Integration is key value prop

---

### Approach 2: Always Generic, Book Context Optional (Rejected)
**Idea:** Single ambient mode that optionally includes book context

**Pros:**
- Simpler mental model
- No mode switching needed

**Cons:**
- Ambiguous when book context is active
- Hard to optimize prompts for both use cases
- Confusing user experience

**Verdict:** Rejected - Explicit modes are clearer

---

### Approach 3: Generic Mode Only, Remove Book Mode (Rejected)
**Idea:** Replace book-specific ambient with unified generic mode

**Pros:**
- Simplest possible implementation
- No mode confusion

**Cons:**
- Loses value of live reading context
- Can't provide page-specific help
- Regression from current functionality

**Verdict:** Rejected - Book mode is valuable and differentiated

---

## Open Questions for V1

### 1. Entry Point Priority
**Question:** What's the primary entry point for generic mode?

**Options:**
- A) Dedicated tab in main navigation
- B) Button on library/home screen
- C) Mode selector in existing ambient view

**Recommendation:** C for V1 (simpler), A for V2 if usage is high

---

### 2. Onboarding Approach
**Question:** How much onboarding for generic mode?

**Options:**
- A) None (discoverable on its own)
- B) One-time tooltip when first seen
- C) Full modal explaining feature

**Recommendation:** B - Brief, dismissible explanation

---

### 3. Default Mode
**Question:** When user opens ambient view, which mode should be default?

**Options:**
- A) Always generic
- B) Always last book read
- C) Smart (generic if no active reading, else book)

**Recommendation:** C - Context-aware default

---

### 4. Conversation Archiving
**Question:** What happens to old generic conversations?

**Options:**
- A) Keep forever (storage cost)
- B) Auto-delete after 30 days
- C) Summarize and archive

**Recommendation:** B for V1, C for V2

---

## Definition of Done

Generic Ambient Mode V1 is **DONE** when:

1. ✅ All launch criteria met
2. ✅ Beta testing complete with positive feedback
3. ✅ Analytics instrumentation working
4. ✅ Documentation updated (user-facing and technical)
5. ✅ App Store release notes written
6. ✅ Team aligned on V2 priorities based on V1 learnings

---

## Communication Plan

### Internal (Team)
- **Week 1:** Share architecture decisions, get feedback
- **Week 2:** Demo mode switching to team
- **Week 3:** Internal dogfooding (team uses it)
- **Week 4:** Beta results review, V2 planning kickoff

### External (Users)
- **Beta launch:** Email to select users with clear instructions
- **Public launch:** Release notes highlighting new capability
- **Week 2:** In-app prompt for users who haven't tried it
- **Month 1:** Blog post or social media showcasing use cases

### Feedback Loops
- **Beta testers:** Daily Slack channel or email thread
- **Early adopters:** In-app feedback form
- **Analytics:** Weekly review of usage patterns
- **Support:** Tag generic-mode-related support requests

---

## Success Definition

V1 is successful if:

1. **Adoption:** >40% of active users try generic mode in first month
2. **Quality:** >85% of conversations stay on-topic (reading)
3. **Value:** >60% of users who try it return 3+ times
4. **Satisfaction:** >4.0/5.0 average rating in feedback survey
5. **Technical:** No major bugs, <1% error rate

If we hit these targets, **invest in V2** with confidence.

If we miss these targets, **investigate and iterate** before expanding scope.

---

## V2 Preview (Pending V1 Results)

Based on successful V1, V2 could include:

**Tier 1 (High Value, Clear Demand):**
- Long-term conversation memory with semantic search
- Siri shortcuts ("Hey Siri, what should I read next?")
- Thematic exploration UI (visual theme maps)
- Reading goal tracking and gentle reminders

**Tier 2 (Medium Value, Needs Validation):**
- Advanced stats visualizations (charts, graphs)
- Home screen widget (recent conversation, suggestions)
- Proactive conversation starters (contextual prompts)
- Export conversations to Notes/Readwise

**Tier 3 (Experimental, High Effort):**
- ML-based intent classification
- Multi-session journey tracking
- Social features (book club prep, shared insights)
- Integration with external services (Goodreads, etc.)

**Decision point:** Month 1 after V1 launch based on usage data

---

## Appendix: Example User Flows

### Flow 1: Discovery - "What should I read next?"

1. User opens Epilogue app
2. Taps Ambient tab (shows mode selector)
3. Sees "Reading Companion" (generic mode) selected by default
4. Taps voice input or types: "What should I read next?"
5. AI responds with 2-3 personalized recommendations based on:
   - Recently finished books
   - Library taste profile
   - Reading patterns (alternates heavy/light)
6. User asks follow-up: "Tell me more about Circe"
7. AI provides context, explains why it matches user's interests
8. User adds book to library (outside ambient mode)
9. Returns later to start reading

**Success:** User got personalized recommendation in <2 minutes

---

### Flow 2: Habits - "Why can't I read consistently?"

1. User hasn't read in 2 weeks (feels guilty)
2. Opens ambient mode, selects generic
3. Types: "Why can't I read more consistently?"
4. AI analyzes reading session data, identifies pattern:
   - Drops off before work trips
   - Struggles to restart after
5. AI explains the pattern user wasn't aware of
6. Suggests concrete strategy: Re-entry ritual (10 pages first morning back)
7. User feels understood and motivated
8. Next trip, implements strategy, returns to tell AI it worked

**Success:** User gains insight and actionable strategy

---

### Flow 3: Mode Switching - Deep dive into finished book

1. User just finished "The Fifth Season"
2. Opens generic ambient, says: "I just finished The Fifth Season"
3. AI congratulates, asks what's resonating
4. User starts detailed discussion about ending
5. AI recognizes book-specific discussion, suggests:
   "Want to switch to The Fifth Season mode? I can reference your exact highlights."
6. User taps [Switch to Book Mode]
7. Gradient shifts from amber to book colors
8. Conversation continues with richer context
9. User reflects on themes, AI surfaces their highlights
10. Finishes satisfied, switches back to generic for next book recommendation

**Success:** Seamless transition between modes based on conversation needs

---

## Summary

Generic Ambient Mode V1 is a **focused, achievable 3-4 week project** that delivers immediate value to users while laying groundwork for future enhancements.

**Key Success Factors:**
1. **Ruthless scope discipline** - Ship V1, learn, iterate
2. **Maximize reuse** - 80% existing code, 20% new
3. **User-driven V2** - Let real usage inform next features
4. **Quality over features** - Better to do 4 things well than 10 things poorly

**Next Steps:**
1. Review and approve this roadmap
2. Begin Week 1 implementation
3. Set up beta tester recruitment
4. Define analytics events for tracking
5. Go build! 🚀
