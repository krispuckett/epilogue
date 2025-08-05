import SwiftUI

// MARK: - Scroll Performance Modifier
struct ScrollPerformance: ViewModifier {
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    @State private var scrollVelocity: CGFloat = 0
    
    let onScrollChanged: ((CGFloat, CGFloat) -> Void)?
    
    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                content
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: PerformanceScrollOffsetPreferenceKey.self,
                                value: geometry.frame(in: .named("scroll")).minY
                            )
                        }
                    )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(PerformanceScrollOffsetPreferenceKey.self) { value in
                let velocity = abs(value - scrollOffset)
                scrollOffset = value
                scrollVelocity = velocity
                
                // Reduce quality during fast scrolling
                if velocity > 50 {
                    if !isScrolling {
                        isScrolling = true
                    }
                } else if isScrolling && velocity < 10 {
                    // Delay quality restoration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if scrollVelocity < 10 {
                            isScrolling = false
                        }
                    }
                }
                
                onScrollChanged?(value, velocity)
            }
            .environment(\.isScrolling, isScrolling)
        }
    }
}

// MARK: - Scroll Offset Preference Key
private struct PerformanceScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Environment Key
private struct ScrollingEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isScrolling: Bool {
        get { self[ScrollingEnvironmentKey.self] }
        set { self[ScrollingEnvironmentKey.self] = newValue }
    }
}

// MARK: - Lazy Loading Container
struct LazyLoadingContainer<Content: View>: View {
    let content: () -> Content
    @State private var hasAppeared = false
    @Environment(\.isScrolling) private var isScrolling
    
    var body: some View {
        Group {
            if hasAppeared || !isScrolling {
                content()
                    .transition(.opacity)
            } else {
                Color.clear
                    .onAppear {
                        // Delay content loading during scroll
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if !isScrolling {
                                hasAppeared = true
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Prefetch Modifier
struct PrefetchModifier: ViewModifier {
    let items: Range<Int>
    let prefetchHandler: (Int) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Prefetch next items
                for i in items {
                    prefetchHandler(i)
                }
            }
    }
}

// MARK: - View Extensions
extension View {
    func scrollPerformance(onScrollChanged: ((CGFloat, CGFloat) -> Void)? = nil) -> some View {
        modifier(ScrollPerformance(onScrollChanged: onScrollChanged))
    }
    
    func lazyLoad() -> some View {
        LazyLoadingContainer { self }
    }
    
    func prefetch(items: Range<Int>, handler: @escaping (Int) -> Void) -> some View {
        modifier(PrefetchModifier(items: items, prefetchHandler: handler))
    }
    
    // 120Hz ProMotion optimization
    func proMotion() -> some View {
        self
            .animation(.interpolatingSpring(mass: 1, stiffness: 500, damping: 30), value: UUID())
            .drawingGroup() // Flatten view hierarchy
    }
}