import SwiftUI

/// Dynamic water ripple effect modifier
/// Creates realistic water ripples with waves, distortion, and spring physics
struct WaterWobbleModifier: ViewModifier {
    let wobblePhase: Double  // Actually used as progress (0-1)

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *), let shader = createRippleShader() {
            content.colorEffect(shader)
        } else {
            // Fallback: no water effect on older iOS
            content
        }
    }

    @available(iOS 17.0, *)
    private func createRippleShader() -> Shader? {
        // wobblePhase is actually the pulse.scale value (1.0 to 5.0)
        // Convert to progress (0.0 to 1.0)
        let progress = min(1.0, (wobblePhase - 1.0) / 4.0)

        // Calculate current ring radius based on scale
        // Base ring is 120pt, scales up to 600pt
        let ringRadius = 60.0 * wobblePhase

        return Shader(
            function: ShaderFunction(library: .default, name: "waterRipple"),
            arguments: [
                .float(progress),
                .float(ringRadius)
            ]
        )
    }
}
