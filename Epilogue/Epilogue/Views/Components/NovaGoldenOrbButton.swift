import SwiftUI

/// Isolated Nova Golden orb used only by the main input and Ambient AI chat input.
struct NovaGoldenOrbButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var startTime = Date.now

    let action: () -> Void
    let size: CGFloat

    init(size: CGFloat, action: @escaping () -> Void) {
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                let elapsed = reduceMotion ? 0 : Float(startTime.distance(to: timeline.date))

                Rectangle()
                    .colorEffect(
                        ShaderLibrary.novaGolden(
                            .boundingRect,
                            .float(elapsed),
                            .float(1.0),
                            .float(2.0),
                            .float(1.0),
                            .float(1.0),
                            .float(1.0),
                            .float(1.0),
                            .color(DesignSystem.Colors.primaryAccent),
                            .color(.white),
                            .color(DesignSystem.Colors.primaryAccent),
                            .color(.white),
                            .color(.black)
                        )
                    )
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
        .buttonStyle(OrbButtonStyle(isPressed: $isPressed))
    }
}
