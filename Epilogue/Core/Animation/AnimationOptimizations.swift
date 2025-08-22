import SwiftUI

// MARK: - 120fps Animation Optimizations for iOS 26 ProMotion

/// Optimized animation configurations for 120fps displays
struct OptimizedAnimations {
    
    // MARK: - Spring Animations (Best for 120fps)
    
    /// Ultra-smooth spring for UI elements (120fps optimized)
    static let smoothSpring = Animation.spring(
        response: 0.35,        // Faster response for ProMotion
        dampingFraction: 0.86, // High damping for smooth stop
        blendDuration: 0       // No blending for crisp animations
    )
    
    /// Bouncy spring for playful interactions
    static let bouncySpring = Animation.spring(
        response: 0.4,
        dampingFraction: 0.65,
        blendDuration: 0
    )
    
    /// Quick spring for immediate feedback
    static let quickSpring = Animation.spring(
        response: 0.25,
        dampingFraction: 0.9,
        blendDuration: 0
    )
    
    /// Gentle spring for subtle movements
    static let gentleSpring = Animation.spring(
        response: 0.5,
        dampingFraction: 0.95,
        blendDuration: 0
    )
    
    // MARK: - Timing Curves (120fps optimized durations)
    
    /// Fast ease for quick transitions (8 frames @ 120fps)
    static let fastEase = Animation.easeInOut(duration: 0.067)
    
    /// Standard ease for normal transitions (20 frames @ 120fps)
    static let standardEase = Animation.easeInOut(duration: 0.167)
    
    /// Smooth ease for comfortable transitions (30 frames @ 120fps)
    static let smoothEase = Animation.easeInOut(duration: 0.25)
    
    /// Slow ease for deliberate transitions (48 frames @ 120fps)
    static let slowEase = Animation.easeInOut(duration: 0.4)
    
    // MARK: - Interactive Animations
    
    /// Interactive spring that responds to velocity
    static let interactiveSpring = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 170,
        damping: 26,
        initialVelocity: 0
    )
    
    // MARK: - Custom Timing Functions
    
    /// Apple's custom ease-in-out curve
    static let appleEaseInOut = Animation.timingCurve(
        0.42, 0, 0.58, 1,
        duration: 0.35
    )
    
    /// Material Design standard curve
    static let materialStandard = Animation.timingCurve(
        0.4, 0, 0.2, 1,
        duration: 0.3
    )
    
    /// Emphasized deceleration (iOS 18 style)
    static let emphasizedDecelerate = Animation.timingCurve(
        0.05, 0.7, 0.1, 1,
        duration: 0.4
    )
}

// MARK: - Animation Performance Helpers

extension View {
    /// Apply 120fps optimized animation
    func animation120fps<V>(_ animation: Animation? = OptimizedAnimations.smoothSpring, value: V) -> some View where V: Equatable {
        self.animation(animation, value: value)
    }
    
    /// High-performance transition
    func transition120fps(_ transition: AnyTransition = .opacity) -> some View {
        self.transition(transition)
    }
    
    /// Optimize for ProMotion displays
    func proMotionOptimized() -> some View {
        self
            .drawingGroup() // Flatten view hierarchy for better performance
            .compositingGroup() // Cache the rendered result
    }
}

// MARK: - Gesture Velocity Helpers

extension DragGesture.Value {
    /// Calculate velocity for spring animations
    var velocity: CGFloat {
        let velocity = CGVector(
            dx: predictedEndLocation.x - location.x,
            dy: predictedEndLocation.y - location.y
        )
        return sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
    }
    
    /// Get normalized velocity for spring initial velocity
    var normalizedVelocity: CGFloat {
        return velocity / 1000
    }
}

// MARK: - Transaction Helpers for 120fps

extension Transaction {
    /// Configure for 120fps performance
    static func with120fps<Result>(_ body: () throws -> Result) rethrows -> Result {
        var transaction = Transaction()
        transaction.isContinuous = true // Enable continuous animations
        transaction.animation = OptimizedAnimations.smoothSpring
        return try withTransaction(transaction, body)
    }
}

// MARK: - Animation Best Practices

/*
 120fps Animation Guidelines for Epilogue:
 
 1. PREFER SPRINGS over timing curves
    - Springs feel more natural at 120fps
    - Use response: 0.25-0.5 for most UI
    - dampingFraction: 0.8-0.95 for smooth stops
 
 2. FRAME-ALIGNED DURATIONS
    - 1 frame @ 120fps = 0.0083s
    - Use multiples: 0.0167, 0.025, 0.033, 0.05
    - Avoid arbitrary durations like 0.3
 
 3. PERFORMANCE OPTIMIZATIONS
    - Use drawingGroup() for complex animations
    - Apply compositingGroup() to cache renders
    - Minimize view hierarchy during animations
 
 4. GESTURE-DRIVEN ANIMATIONS
    - Use velocity from gestures
    - Apply interactiveSpring for drag gestures
    - Match animation to gesture velocity
 
 5. REDUCE OVERDRAW
    - Avoid overlapping animated views
    - Use opacity sparingly
    - Prefer transform animations
 
 6. STATE CHANGES
    - Batch state updates with withAnimation
    - Use Transaction for complex updates
    - Avoid rapid successive animations
 
 7. SCROLLING PERFORMANCE
    - Use LazyVStack/LazyHStack
    - Implement proper cell reuse
    - Minimize work in onAppear/onDisappear
 
 8. TESTING
    - Test on ProMotion devices (iPhone 13 Pro+)
    - Use Instruments to verify 120fps
    - Check for frame drops during animations
 */