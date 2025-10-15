import SwiftUI
import Combine

// MARK: - iOS 18 Scroll Performance Optimizations for 120Hz ProMotion
extension ScrollView {
    /// Optimizes ScrollView for buttery smooth 120Hz scrolling on iPhone 16 Pro
    func ultraSmoothScrolling() -> some View {
        self
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.immediately)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, 0, for: .scrollContent)
    }
}

// MARK: - LazyVStack Optimizations
extension LazyVStack {
    /// Optimizes LazyVStack for 120Hz rendering
    func optimizedForProMotion() -> some View {
        self
            .scrollTargetLayout()
            .transaction { transaction in
            transaction.animation = nil
        } // Disable default animations
    }
}

// MARK: - View Extensions for Scroll Content
extension View {
    /// Optimizes any view for display within a ScrollView at 120Hz
    func scrollContentOptimized() -> some View {
        self
            .drawingGroup() // Rasterize complex views
            .compositingGroup() // Flatten view hierarchy
            .transaction { transaction in
                transaction.animation = nil
            } // Disable implicit animations
    }
    
    /// Applies 120Hz ProMotion-optimized spring animation
    func proMotionSpring() -> some View {
        self.animation(.interpolatingSpring(
            mass: 0.3,
            stiffness: 600,
            damping: 32
        ), value: UUID())
    }
    
    /// Disable all animations during scrolling
    func scrollingAnimationDisabled() -> some View {
        self.transaction { transaction in
            transaction.animation = nil
        }
    }
}

// MARK: - Scroll Performance Monitor
struct ScrollPerformanceMonitor: ViewModifier {
    @State private var lastFrameTime = CACurrentMediaTime()
    @State private var frameRate: Double = 120
    
    func body(content: Content) -> some View {
        content
            .onReceive(Timer.publish(every: 1.0/120.0, on: .main, in: .common).autoconnect()) { _ in
                let currentTime = CACurrentMediaTime()
                let frameDuration = currentTime - lastFrameTime
                frameRate = 1.0 / frameDuration
                lastFrameTime = currentTime
                
                #if DEBUG
                if frameRate < 100 {
                    #if DEBUG
                    print("⚠️ Frame drop detected: \(Int(frameRate)) FPS")
                    #endif
                }
                #endif
            }
    }
}

// MARK: - Optimized Grid Layout
struct OptimizedLazyVGrid<Content: View>: View {
    let columns: [GridItem]
    let spacing: CGFloat
    let content: () -> Content
    
    init(columns: [GridItem], spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            content()
        }
        .scrollTargetLayout()
        .transaction { transaction in
            transaction.animation = nil
        }
    }
}