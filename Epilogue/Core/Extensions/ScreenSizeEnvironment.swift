import SwiftUI

// MARK: - Screen Size Environment for iOS 26 Compliance

/// Environment key for screen size to replace deprecated UIScreen.main
private struct ScreenSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = CGSize(width: 390, height: 844) // iPhone 14 default
}

/// Environment key for display scale
private struct DisplayScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 2.0
}

extension EnvironmentValues {
    /// Current screen size from window scene
    var screenSize: CGSize {
        get { self[ScreenSizeKey.self] }
        set { self[ScreenSizeKey.self] = newValue }
    }
    
    /// Current display scale
    var displayScale: CGFloat {
        get { self[DisplayScaleKey.self] }
        set { self[DisplayScaleKey.self] = newValue }
    }
}

// MARK: - View Extensions

extension View {
    /// Inject screen size into environment from GeometryReader
    func injectScreenSize() -> some View {
        GeometryReader { geometry in
            self
                .environment(\.screenSize, geometry.size)
                .environment(\.displayScale, UITraitCollection.current.displayScale)
        }
    }
    
    /// Get screen bounds safely without UIScreen.main
    func withScreenBounds<Content: View>(
        @ViewBuilder content: @escaping (CGSize) -> Content
    ) -> some View {
        GeometryReader { geometry in
            content(geometry.size)
        }
    }
}

// MARK: - Safe Screen Access

struct ScreenInfo {
    /// Get screen size safely for iOS 26
    static func screenSize(from view: UIView?) -> CGSize {
        // Try to get from window scene
        if let windowScene = view?.window?.windowScene {
            return windowScene.screen.bounds.size
        }
        
        // Fallback to trait collection
        if let window = view?.window {
            return window.bounds.size
        }
        
        // Last resort default
        return CGSize(width: 390, height: 844)
    }
    
    /// Get display scale safely for iOS 26
    static func displayScale(from view: UIView?) -> CGFloat {
        // Try to get from window scene
        if let windowScene = view?.window?.windowScene {
            return windowScene.screen.scale
        }
        
        // Fallback to trait collection
        return view?.traitCollection.displayScale ?? 2.0
    }
    
    /// Get safe area insets
    static func safeAreaInsets(from view: UIView?) -> UIEdgeInsets {
        return view?.safeAreaInsets ?? .zero
    }
}

// MARK: - SwiftUI Helpers

struct ScreenSizeReader: ViewModifier {
    @State private var screenSize: CGSize = .zero
    let onChange: (CGSize) -> Void
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: SizePreferenceKey.self, value: geometry.size)
                }
            )
            .onPreferenceChange(SizePreferenceKey.self) { size in
                if size != screenSize {
                    screenSize = size
                    onChange(size)
                }
            }
    }
}

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    /// Read screen size changes
    func onScreenSizeChange(perform: @escaping (CGSize) -> Void) -> some View {
        modifier(ScreenSizeReader(onChange: perform))
    }
}