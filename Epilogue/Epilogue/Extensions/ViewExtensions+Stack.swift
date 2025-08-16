import SwiftUI
import UIKit
import Combine

// MARK: - Parallax Effect
extension View {
    func parallaxEffect(multiplier: CGFloat = 0.1) -> some View {
        GeometryReader { geometry in
            self
                .offset(y: geometry.frame(in: .global).minY * multiplier)
        }
    }
}


// MARK: - Shake Detection
struct ShakeDetector: ViewModifier {
    let onShake: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                onShake()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeDetector(onShake: action))
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

// MARK: - Shake Detection Window
class ShakeDetectingWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}






