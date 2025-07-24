import SwiftUI

struct LiteraryLoadingView: View {
    let message: String?
    @State private var currentQuote: LiteraryQuote
    @State private var rotationAngle: Double = 0
    @State private var quoteOpacity: Double = 0
    
    init(message: String? = nil) {
        self.message = message
        self._currentQuote = State(initialValue: LiteraryQuotes.randomQuote())
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Warm amber spinner
            ZStack {
                Circle()
                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2), lineWidth: 3)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.26),
                                Color(red: 1.0, green: 0.7, blue: 0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
            }
            
            // Loading message if provided
            if let message = message {
                Text(message)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
            }
            
            // Literary quote with Georgia italic
            VStack(spacing: 8) {
                Text(currentQuote.text)
                    .font(.custom("Georgia", size: 15))
                    .italic()
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                
                Text("— \(currentQuote.author)")
                    .font(.custom("Georgia", size: 13))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.7))
            }
            .opacity(quoteOpacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                    quoteOpacity = 1
                }
            }
        }
        .padding(.horizontal, 40)
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
        Color(red: 0.11, green: 0.105, blue: 0.102)
            .ignoresSafeArea()
        
        LiteraryLoadingView(message: "Searching for books...")
    }
}