import SwiftUI

struct GlassPrinciplesDemo: View {
    var body: some View {
        ZStack {
            // Rich background to show translucency
            AnimatedGradientBackground()
            
            VStack(spacing: 40) {
                Text("iOS 26 Glass Effect Principles")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 60)
                
                // Key Principle: NO backgrounds before glass
                VStack(alignment: .leading, spacing: 20) {
                    Text("❌ WRONG: Background blocks glass")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack {
                        Text("Code:")
                            .foregroundStyle(.white.opacity(0.7))
                        Text(".background(Color.white.opacity(0.2))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.orange)
                    }
                    
                    // Wrong implementation
                    Button("This won't be glass") {}
                        .foregroundStyle(.white)
                        .frame(width: 250, height: 60)
                        .background(RoundedRectangle(cornerRadius: 15).fill(.white.opacity(0.2)))
                        .glassEffect()
                }
                .padding(.horizontal, 30)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text("✅ CORRECT: No background")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack {
                        Text("Code:")
                            .foregroundStyle(.white.opacity(0.7))
                        Text(".glassEffect() only")
                            .font(.caption.monospaced())
                            .foregroundStyle(.green)
                    }
                    
                    // Correct implementation
                    Button("This is proper glass") {}
                        .foregroundStyle(.white)
                        .frame(width: 250, height: 60)
                        .glassEffect()
                }
                .padding(.horizontal, 30)
                
                // Glass with shape clipping
                VStack(spacing: 20) {
                    Text("Glass with Shape Clipping")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 20) {
                        Button {
                            // Action
                        } label: {
                            Image(systemName: "star.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                        }
                        .glassEffect(in: Circle())
                        
                        Button {
                            // Action
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .frame(width: 80, height: 80)
                        }
                        .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                .purple,
                .blue,
                .cyan,
                .green,
                .yellow,
                .orange,
                .red,
                .purple
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

#Preview {
    GlassPrinciplesDemo()
}