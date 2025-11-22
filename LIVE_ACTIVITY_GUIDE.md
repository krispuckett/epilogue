# Live Activities Auto-Restart Guide

## The Problem

iOS Live Activities have hard time limits:
- **8 hours** maximum in Dynamic Island
- **12 hours** maximum on Lock Screen (8h active + 4h after removal)
- **Automatic termination** by iOS after these limits
- **No extension mechanism** - can't ask for more time

For Epilogue's ambient reading mode that should run for hours, this is a critical bug.

## The Solution

Implemented an **auto-restart pattern** inspired by Raycast's approach:
- Pre-emptively restart activities before hitting the limit
- Seamlessly transfer state between old and new activities
- Make the transition invisible to users
- Handle errors gracefully with retry logic

---

## Architecture

### LiveActivityLifecycleManager

**Location:** `Epilogue/Services/Ambient/LiveActivityLifecycleManager.swift`

Key features:
1. **Lifecycle Monitoring** - Checks activity age every 60 seconds
2. **Pre-emptive Restart** - Restarts at 7 hours (1 hour before iOS limit)
3. **State Preservation** - Maintains session state across restarts
4. **Error Recovery** - Exponential backoff retries (2s, 4s, 8s)
5. **Background Support** - Monitors even when app is backgrounded

### How It Works

```
[Activity 1: 0-7h] → [Restart] → [Activity 2: 7-14h] → [Restart] → [Activity 3: 14-21h] ...
                ↓
         State Preserved:
         - Book title
         - Captured count
         - Last transcript
         - Total duration
```

### Restart Process

1. **Check Timer** (every 60s) - Monitors activity age
2. **Hit 7 Hours** - Triggers restart sequence
3. **Preserve State** - Captures current session data
4. **End Old Activity** - Dismisses immediately
5. **100ms Delay** - Ensures clean transition
6. **Create New Activity** - With preserved state
7. **Continue** - User sees no interruption

---

## Configuration

### Info.plist

Add this key to enable frequent updates:

```xml
<key>NSSupportsLiveActivitiesFrequentUpdates</key>
<true/>
```

### Background Modes

Required capabilities (should already be configured):
- ✅ Audio (for background audio playback)
- ✅ Background fetch (optional, helps with monitoring)

---

## Usage

### Basic Integration

```swift
import LiveActivityLifecycleManager

// Start ambient session
await LiveActivityLifecycleManager.shared.startSession()

// Update content
await LiveActivityLifecycleManager.shared.updateContent(
    bookTitle: "The Great Gatsby",
    capturedCount: 5,
    isListening: true,
    lastTranscript: "In my younger and more vulnerable years..."
)

// End session
await LiveActivityLifecycleManager.shared.endSession()
```

### Migration from Old Manager

The old `AmbientLiveActivityManager` is now a thin wrapper. Your existing code continues to work:

```swift
// This still works - automatically delegates to new manager
await AmbientLiveActivityManager.shared.startActivity()
await AmbientLiveActivityManager.shared.updateActivity(bookTitle: "Test")
await AmbientLiveActivityManager.shared.endActivity()
```

### Monitoring Status

```swift
let manager = LiveActivityLifecycleManager.shared

// Check if active
if manager.isActive {
    print("Session running")
}

// Get current activity
if let activity = manager.currentActivity {
    print("Activity ID: \(activity.id)")
}

// Session metrics
print("Session duration: \(manager.totalSessionDuration)")
```

---

## Testing

### Quick Testing (Fast Restart Cycles)

For development, you want to test restarts without waiting 7 hours.

**Modify restart interval temporarily:**

In `LiveActivityLifecycleManager.swift:27`, change:
```swift
// Production: 7 hours
private let restartInterval: TimeInterval = 7 * 60 * 60

// Testing: 2 minutes
private let restartInterval: TimeInterval = 120
```

**Don't forget to change back for production!**

### Test State Preservation

```swift
#if DEBUG
await LiveActivityTesting.shared.testStatePreservation()
#endif
```

Expected output:
```
🧪 Testing state preservation...
📦 State before restart:
  - Book: Test Book
  - Count: 42
  - Transcript: This is a test transcript...
🔄 Forcing restart...
📦 State after restart:
  - Book: Test Book
  - Count: 42
  - Transcript: This is a test transcript...
✅ State preservation successful
```

### Test Background Behavior

```swift
#if DEBUG
await LiveActivityTesting.shared.testBackgroundBehavior()
#endif
```

Instructions:
1. Start test
2. Background app (swipe up)
3. Wait 2-5 minutes
4. Return to app
5. Check console for background task logs

### Simulate Near Expiration

```swift
#if DEBUG
await LiveActivityTesting.shared.simulateNearExpiration()
#endif
```

Forces an immediate restart to test the seamless transition.

### Production Validation

Before release, run:
```swift
#if DEBUG
await LiveActivityTesting.shared.validateProductionReadiness()
#endif
```

Checks:
- ✅ Info.plist configuration
- ✅ Live Activities enabled
- ✅ State size < 4KB
- ✅ Restart interval configured

### Testing UI

SwiftUI view for interactive testing:

```swift
#if DEBUG
import SwiftUI

struct MyView: View {
    var body: some View {
        LiveActivityTestingView()
    }
}
#endif
```

---

## Debugging

### Console Logs

The manager emits detailed logs in DEBUG builds:

**Session Start:**
```
✅ LiveActivity session started (restart interval: 7.0h)
✅ Live Activity created: ABC-123-DEF
```

**Lifecycle Monitoring:**
```
👁️ Lifecycle monitoring started (check every 60.0s)
⏱️ Activity age: 0.5h / 7.0h
⏱️ Activity age: 1.0h / 7.0h
...
⏱️ Activity age: 7.0h / 7.0h
⏰ Restart interval reached (7.0h), restarting...
```

**Restart:**
```
🔄 Restarting Live Activity...
✅ Live Activity restarted successfully
```

**State Recovery:**
```
♻️ Recovered existing Live Activity: XYZ-789-ABC
⏰ Existing activity is old (7.5h), restarting...
```

**Errors:**
```
❌ Failed to create Live Activity: <error>
⏳ Retrying in 2.0s (attempt 1/3)
```

**Background:**
```
📱 App entering background
📱 Background task started
📱 App entering foreground
📱 Background task ended
```

### Common Issues

#### 1. Activity Dies After 8 Hours

**Symptoms:**
- Activity disappears from Dynamic Island
- No restart occurs

**Causes:**
- Restart interval set too high (> 8 hours)
- Lifecycle monitoring stopped
- App terminated by iOS

**Debug:**
```swift
// Check if monitoring is running
if manager.isActive {
    if let timeLeft = manager.timeUntilRestart() {
        print("Restart in: \(timeLeft)s")
    }
}
```

**Fix:**
- Verify `restartInterval` is < 8 hours
- Check lifecycle timer is running
- Ensure app has audio background mode

#### 2. State Lost on Restart

**Symptoms:**
- Book title disappears
- Captured count resets
- Transcript lost

**Causes:**
- State not preserved before restart
- Encoding/decoding error

**Debug:**
```swift
// Add breakpoint in preserveState()
private func preserveState(_ state: AmbientActivityAttributes.ContentState) {
    preservedState = PreservedSessionState(...)
    print("📦 Preserved: \(preservedState)")
}
```

**Fix:**
- Ensure all state updates call `preserveState()`
- Verify `PreservedSessionState` codable conformance
- Check state doesn't exceed 4KB

#### 3. Restart Fails

**Symptoms:**
- Activity ends and doesn't come back
- Console shows retry attempts

**Causes:**
- Live Activities disabled
- Rate limiting by iOS
- System pressure (low battery, etc.)

**Debug:**
```swift
let authInfo = ActivityAuthorizationInfo()
print("Enabled: \(authInfo.areActivitiesEnabled)")
print("Retries: \(restartRetries)/\(maxRestartRetries)")
```

**Fix:**
- Check Settings → [Your App] → Live Activities
- Wait for retry backoff (2s, 4s, 8s)
- Check device isn't in Low Power Mode

#### 4. Background Task Killed

**Symptoms:**
- Restart doesn't happen when app backgrounded
- Activity dies silently

**Causes:**
- Background task exceeded time limit (~30s-3min)
- App suspended by iOS
- No background modes configured

**Debug:**
```swift
// Monitor background task lifetime
private func beginBackgroundTask() {
    print("📱 Background task started at \(Date())")
    // ... existing code
}

private func endBackgroundTask() {
    print("📱 Background task ended at \(Date())")
    // ... existing code
}
```

**Fix:**
- Ensure audio mode is active
- Keep audio playing (silent if needed)
- Don't rely on background tasks > 30s

### Crash Scenarios

#### Activity Already Exists Error

```
Error Domain=ActivityKit.ActivityError Code=1
"Activity with this ID already exists"
```

**Cause:** Trying to create activity with duplicate ID

**Fix:** Check for existing activities first (already handled in `recoverExistingActivity()`)

#### State Too Large Error

```
Error Domain=ActivityKit.ActivityError Code=3
"Activity state exceeds maximum size"
```

**Cause:** State data > 4KB

**Fix:** Reduce transcript length, use shorter book titles

**Prevention:**
```swift
// Truncate transcript if needed
let maxTranscriptLength = 200
let truncated = transcript.prefix(maxTranscriptLength)
```

---

## Production Monitoring

### Metrics to Track

1. **Restart Success Rate**
   - How many restarts succeed vs. fail
   - Track in analytics

2. **Session Duration**
   - Average ambient session length
   - Longest session without failure

3. **Restart Frequency**
   - Restarts per session
   - Should be ~1 per 7 hours

4. **Failure Modes**
   - What errors occur most
   - When do retries exhaust

### Logging for Production

Add telemetry at key points:

```swift
// In restartActivity()
Analytics.track("live_activity_restart", properties: [
    "age_hours": age / 3600,
    "session_duration": totalSessionDuration,
    "captured_count": preservedState?.capturedCount ?? 0
])

// In handleRestartFailure()
Analytics.track("live_activity_restart_failed", properties: [
    "retry_count": restartRetries,
    "error": error.localizedDescription
])
```

### User-Facing Indicators

Consider showing restart status in UI:

```swift
// Subtle indicator that restart is coming soon
if let timeLeft = manager.timeUntilRestart(), timeLeft < 300 {
    // Show: "Refreshing connection in 5 min..."
}
```

---

## Performance Considerations

### Battery Impact

**Current approach:**
- Timers every 60s (lifecycle) and 10s (duration update)
- Background tasks when app backgrounded
- Audio session for background mode

**Optimization opportunities:**
- Reduce check interval to 5 minutes (but less responsive)
- Only update duration when user views activity
- Use push notifications instead of timers (requires server)

### Memory Usage

**Per restart:**
- Creates new Activity object
- Old activity deallocated
- Preserved state kept in memory

**Total impact:** Minimal (~1KB per activity)

### Network Usage

Live Activities don't use network unless you're using push notifications.
Current implementation: **0 network usage**

---

## Advanced Patterns

### Server-Driven Restart

Instead of timer-based restart, use push notifications:

```swift
// Server sends push at 6h 50min mark
{
  "aps": {
    "timestamp": 1234567890,
    "event": "restart-needed",
    "content-state": { ... }
  }
}
```

Benefits:
- More reliable than timers
- Works even if app killed
- Centralized control

Drawbacks:
- Requires server infrastructure
- Network dependency
- APNs rate limits

### Progressive Restart Intervals

Adjust interval based on session age:

```swift
private var restartInterval: TimeInterval {
    let sessionAge = totalSessionDuration

    if sessionAge < 1 * 60 * 60 {  // First hour
        return 30 * 60  // Restart every 30 min (more frequent initially)
    } else if sessionAge < 4 * 60 * 60 {  // Next 3 hours
        return 2 * 60 * 60  // Every 2 hours
    } else {
        return 7 * 60 * 60  // Every 7 hours (longest safe interval)
    }
}
```

### Restart on Content Change

Restart when significant state changes:

```swift
func updateContent(...) async {
    // Check if we should restart early
    if shouldRestartEarly() {
        await restartActivity()
    }

    // Normal update
    await activity.update(...)
}

private func shouldRestartEarly() -> Bool {
    guard let startTime = activityStartTime else { return false }
    let age = Date().timeIntervalSince(startTime)

    // Restart if > 6 hours and about to change books
    return age > 6 * 60 * 60
}
```

---

## FAQ

### Q: Why 7 hours instead of 8?

**A:** Conservative buffer. Better to restart at 7h smoothly than risk iOS killing it at 8h.

### Q: Can users notice the restart?

**A:** In testing, no. The 100ms delay is imperceptible, and state preservation makes it seamless.

### Q: What happens if restart fails?

**A:** Exponential backoff retries (2s, 4s, 8s). After 3 failures, the activity ends gracefully.

### Q: Does this work in Low Power Mode?

**A:** Maybe. iOS is more aggressive in Low Power Mode. Test thoroughly.

### Q: Can I extend to 24+ hours?

**A:** Yes! With 7-hour restarts, you get: 7h × 100 restarts = 700 hours theoretically. Practically, battery and iOS resource limits apply.

### Q: What about Dynamic Island vs. Lock Screen?

**A:** Restart applies to both. After 8h total, iOS moves activity to Lock Screen only (for up to 4 more hours). Our restart prevents this.

### Q: Do I need a server?

**A:** No. Current implementation is entirely client-side.

### Q: How do I test in production?

**A:** Start with 2-hour restart interval for first week, monitor analytics, gradually increase to 7 hours.

---

## Migration Checklist

- [ ] Add `NSSupportsLiveActivitiesFrequentUpdates` to Info.plist
- [ ] Replace calls to `AmbientLiveActivityManager` with `LiveActivityLifecycleManager`
- [ ] Test state preservation with forced restarts
- [ ] Test background behavior (app backgrounded for 5+ minutes)
- [ ] Validate production readiness with `LiveActivityTesting.shared.validateProductionReadiness()`
- [ ] Set restart interval appropriately:
  - [ ] Development: 2-5 minutes for quick testing
  - [ ] Beta: 2 hours for safety
  - [ ] Production: 7 hours for optimal UX
- [ ] Add analytics for restart events
- [ ] Document user-facing behavior (if any)
- [ ] Test on various iOS versions (17, 18)
- [ ] Test on various device states (low battery, Low Power Mode, etc.)

---

## References

### iOS Documentation
- [ActivityKit | Apple Developer](https://developer.apple.com/documentation/activitykit)
- [Updating Live Activities | Apple Developer](https://developer.apple.com/documentation/activitykit/updating-and-ending-your-live-activity-with-activitykit-push-notifications)
- [Live Activities Design Guidelines](https://developer.apple.com/design/human-interface-guidelines/live-activities)

### Inspiration
- Raycast's ElevenLabs integration (6-minute restart cycle)
- Fitness tracking apps with multi-hour Live Activities
- Navigation apps with continuous Dynamic Island presence

---

## Support

### Debugging Issues

1. Enable verbose logging (already in DEBUG builds)
2. Run `LiveActivityTesting.shared.validateProductionReadiness()`
3. Check console for error patterns
4. Review section: "Common Issues" above

### Filing Bugs

Include:
- iOS version
- Device model
- Session duration before failure
- Console logs (last 50 lines before issue)
- Steps to reproduce

### Performance Issues

If battery drain or memory issues:
1. Reduce `checkInterval` to 5 minutes
2. Reduce `updateTimer` to 30 seconds
3. Profile with Instruments
4. Check for retain cycles in lifecycle monitoring

---

## Changelog

### v1.0.0 - Initial Implementation
- LiveActivityLifecycleManager with 7-hour restart
- State preservation across restarts
- Error recovery with exponential backoff
- Background monitoring support
- Comprehensive testing utilities

### Future Enhancements
- [ ] Server-driven restart via push notifications
- [ ] Adaptive restart intervals based on session age
- [ ] Progressive image loading in widget
- [ ] Analytics dashboard for restart metrics
- [ ] Restart scheduling based on user patterns
