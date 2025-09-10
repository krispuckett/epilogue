import SwiftUI

// MARK: - Materialize-style appearance modifier
struct MaterializeModifier: ViewModifier {
    let order: Int
    var baseDelay: Double = 0.015
    var maxDelay: Double = 0.25
    
    @State private var appeared = false
    
    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1.0 : 0.98)
            .blur(radius: appeared ? 0 : 6)
            .offset(y: appeared ? 0 : 6)
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: appeared)
            .task {
                guard !appeared else { return }
                let delay = min(maxDelay, Double(order) * baseDelay)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                withAnimation {
                    appeared = true
                }
            }
    }
}

extension View {
    func materialize(order: Int, baseDelay: Double = 0.015, maxDelay: Double = 0.25) -> some View {
        modifier(MaterializeModifier(order: order, baseDelay: baseDelay, maxDelay: maxDelay))
    }
}

