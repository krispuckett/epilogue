import SwiftUI

struct LiteraryLoadingView: View {
    let message: String?
    @State private var currentQuote: LiteraryQuote
    @State private var rotationAngle: Double = 0
    @State private var quoteOpacity: Double = 0
    @State private var bookScale: CGFloat = 0.8
    @State private var bookOpacity: Double = 0
    
    init(message: String? = nil) {
        self.message = message
        self._currentQuote = State(initialValue: LiteraryQuotes.randomQuote())
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated book icon
            ZStack {
                // Background glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                DesignSystem.Colors.primaryAccent.opacity(0.3),
                                DesignSystem.Colors.primaryAccent.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 10)
                
                // Book icon with page flip animation
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryAccent,
                                Color(red: 1.0, green: 0.7, blue: 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(bookScale)
                    .opacity(bookOpacity)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            bookScale = 1.0
                            bookOpacity = 1.0
                        }
                        
                        // Gentle pulsing animation
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            bookScale = 1.05
                        }
                    }
            }
            
            // Loading message with progress dots
            HStack(spacing: 4) {
                if let message = message {
                    Text(message)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.9))
                }
                
                // Animated dots
                HStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(DesignSystem.Colors.primaryAccent)
                            .frame(width: 4, height: 4)
                            .opacity(rotationAngle > Double(index * 120) ? 1.0 : 0.3)
                            .animation(.easeInOut(duration: 0.5), value: rotationAngle)
                    }
                }
            }
            
            // Literary quote with better styling
            VStack(spacing: 12) {
                Text(currentQuote.text)
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.5))
                        .frame(width: 20, height: 1)
                    
                    Text(currentQuote.author)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                    
                    Rectangle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.5))
                        .frame(width: 20, height: 1)
                }
            }
            .opacity(quoteOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).delay(0.5)) {
                    quoteOpacity = 1
                }
            }
        }
        .padding(.horizontal, 50)
        .frame(maxWidth: 400) // Limit width for better readability
        .onAppear {
            // Rotate quotes every 4 seconds
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    quoteOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    currentQuote = LiteraryQuotes.randomQuote()
                    withAnimation(.easeInOut(duration: 0.5)) {
                        quoteOpacity = 1
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        DesignSystem.Colors.surfaceBackground
            .ignoresSafeArea()
        
        LiteraryLoadingView(message: "Searching for books...")
    }
}