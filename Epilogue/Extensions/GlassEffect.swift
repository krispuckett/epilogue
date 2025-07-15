import SwiftUI

// MARK: - Glass Effect Extensions for iOS 26 Compatibility
// This provides backward compatibility for the glass effect API

extension View {
    /// Applies a glass effect to the view (iOS 26 style)
    @ViewBuilder
    func glassEffect() -> some View {
        if #available(iOS 26.0, *) {
            // Use the real iOS 26 glass effect when available
            self.modifier(iOS26GlassEffect())
        } else {
            // Fallback to material blur for older versions
            self.background(.ultraThinMaterial)
        }
    }
    
    /// Applies a glass effect with a custom shape
    @ViewBuilder
    func glassEffect<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            // Use the real iOS 26 glass effect when available
            self.modifier(iOS26GlassEffectWithShape(shape: shape))
        } else {
            // Fallback to material blur for older versions
            self.background(shape.fill(.ultraThinMaterial))
        }
    }
    
    /// Applies a glass effect with identity for animations
    @ViewBuilder
    func glassEffectID<S: Shape>(_ id: String, in namespace: Namespace.ID, shape: S = RoundedRectangle(cornerRadius: 0)) -> some View {
        if #available(iOS 26.0, *) {
            // Use the real iOS 26 glass effect when available
            self.modifier(iOS26GlassEffectWithID(id: id, namespace: namespace, shape: AnyShape(shape)))
        } else {
            // Fallback to material blur with matched geometry for older versions
            self.background(
                AnyShape(shape)
                    .fill(.ultraThinMaterial)
                    .matchedGeometryEffect(id: id, in: namespace)
            )
        }
    }
}

// MARK: - iOS 26 Glass Effect Modifiers

@available(iOS 26.0, *)
private struct iOS26GlassEffect: ViewModifier {
    func body(content: Content) -> some View {
        // This would use the actual iOS 26 glassEffect() API
        // For now, fallback to material since iOS 26 isn't available yet
        content.background(.ultraThinMaterial)
    }
}

@available(iOS 26.0, *)
private struct iOS26GlassEffectWithShape<S: Shape>: ViewModifier {
    let shape: S
    
    func body(content: Content) -> some View {
        // This would use the actual iOS 26 glassEffect(in:) API
        // For now, fallback to material since iOS 26 isn't available yet
        content.background(shape.fill(.ultraThinMaterial))
    }
}

@available(iOS 26.0, *)
private struct iOS26GlassEffectWithID: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    let shape: AnyShape
    
    func body(content: Content) -> some View {
        // This would use the actual iOS 26 glassEffect API with ID
        // For now, fallback to material since iOS 26 isn't available yet
        content.background(
            shape
                .fill(.ultraThinMaterial)
                .matchedGeometryEffect(id: id, in: namespace)
        )
    }
}

// MARK: - Type-erased Shape for iOS 26 compatibility
private struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - Glass Effect Container
struct GlassEffectContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .glassEffect(in: RoundedRectangle(cornerRadius: 20))
    }
}