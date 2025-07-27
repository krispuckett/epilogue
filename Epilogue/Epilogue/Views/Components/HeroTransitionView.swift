import SwiftUI

// MARK: - Hero Transition View
struct HeroTransitionView: View {
    let isPresented: Bool
    let sourceFrame: CGRect
    let onComplete: () -> Void
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            if isPresented {
                // Expanding circle from waveform icon
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .orange.opacity(0.8),
                                .orange.opacity(0.4),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 400
                        )
                    )
                    .frame(
                        width: 20 + (UIScreen.main.bounds.width * 2) * animationProgress,
                        height: 20 + (UIScreen.main.bounds.height * 2) * animationProgress
                    )
                    .position(
                        x: sourceFrame.midX,
                        y: sourceFrame.midY
                    )
                    .animation(
                        .easeInOut(duration: 0.8),
                        value: animationProgress
                    )
                    .onAppear {
                        animationProgress = 1.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            onComplete()
                        }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Waveform Hero Button
struct WaveformHeroButton: View {
    let onTap: () -> Void
    @State private var isPressed = false
    @State private var showHeroTransition = false
    @State private var buttonFrame: CGRect = .zero
    
    var body: some View {
        Button {
            // Start hero transition
            showHeroTransition = true
        } label: {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.orange)
                .symbolEffect(.variableColor.iterative, options: .repeating)
                .scaleEffect(isPressed ? 1.1 : 1.0)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        // Capture button frame in global coordinates
                        buttonFrame = geometry.frame(in: .global)
                    }
            }
        )
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false }
        )
        .overlay {
            if showHeroTransition {
                HeroTransitionView(
                    isPresented: showHeroTransition,
                    sourceFrame: buttonFrame,
                    onComplete: {
                        showHeroTransition = false
                        onTap()
                    }
                )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
    }
}

// MARK: - Press Events ViewModifier
struct PressEvents: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
                // onEnded
            } onPressingChanged: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.modifier(PressEvents(onPress: onPress, onRelease: onRelease))
    }
}

#Preview {
    VStack(spacing: 40) {
        Text("Hero Transition Preview")
            .font(.title)
            .foregroundStyle(.white)
        
        WaveformHeroButton {
            print("Hero transition completed!")
        }
        
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .preferredColorScheme(.dark)
}