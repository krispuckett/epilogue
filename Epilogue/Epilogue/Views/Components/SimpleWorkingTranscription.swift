import SwiftUI

struct SimpleWorkingTranscription: View {
    let text: String
    @State private var displayText: String = ""
    @State private var opacity: Double = 0
    
    // Clean, simple animation
    var body: some View {
        GeometryReader { geometry in
            Text(displayText)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .opacity(opacity)
                .animation(.easeIn(duration: 0.3), value: displayText)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: geometry.size.width - 80)
                .glassEffect()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onChange(of: text) { _, newText in
                    // Simple fade transition
                    withAnimation(.easeOut(duration: 0.2)) {
                        opacity = 0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        displayText = String(newText.suffix(80)) // Keep last 80 chars
                        withAnimation(.easeIn(duration: 0.3)) {
                            opacity = 1
                        }
                    }
                }
                .onAppear {
                    displayText = String(text.suffix(80))
                    withAnimation(.easeIn(duration: 0.3)) {
                        opacity = 1
                    }
                }
        }
    }
}