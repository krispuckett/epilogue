import SwiftUI

struct ReadingProgressIndicator: View {
    let currentPage: Int
    let totalPages: Int
    let width: CGFloat
    @State private var animateProgress = false
    
    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
    
    var progressText: String {
        return "\(currentPage) of \(totalPages)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Progress text
            Text(progressText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
            
            // Amber bookmark ribbon progress bar
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: width, height: 2)
                    .clipShape(Capsule())
                
                // Progress fill with bookmark ribbon effect
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.7, blue: 0.3), // Bright amber
                                Color(red: 1.0, green: 0.55, blue: 0.26) // Deep amber
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: animateProgress ? width * progress : 0, height: 2)
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), radius: 2, y: 1)
                    .overlay(alignment: .trailing) {
                        // Bookmark ribbon tail effect
                        if progress > 0.1 {
                            ZStack {
                                // Small notch to simulate bookmark ribbon
                                Path { path in
                                    let height: CGFloat = 6
                                    let width: CGFloat = 4
                                    
                                    path.move(to: CGPoint(x: 0, y: -height/2))
                                    path.addLine(to: CGPoint(x: width, y: -height/2))
                                    path.addLine(to: CGPoint(x: width/2, y: 0))
                                    path.addLine(to: CGPoint(x: width, y: height/2))
                                    path.addLine(to: CGPoint(x: 0, y: height/2))
                                    path.closeSubpath()
                                }
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                                .shadow(color: .black.opacity(0.2), radius: 1, x: 0.5, y: 0.5)
                            }
                            .offset(x: 2)
                        }
                    }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                animateProgress = true
            }
        }
    }
}

// MARK: - Book Progress Extension
extension Book {
    var currentPage: Int {
        // For demo purposes, generate a realistic reading progress
        // In a real app, this would come from user data
        guard let totalPages = pageCount, totalPages > 0 else { return 0 }
        
        switch readingStatus {
        case .wantToRead:
            return 0
        case .currentlyReading:
            return Int.random(in: 10...(totalPages - 50))
        case .finished:
            return totalPages
        }
    }
    
    var progressPercentage: Double {
        guard let totalPages = pageCount, totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
}

#Preview {
    ZStack {
        Color(red: 0.11, green: 0.105, blue: 0.102)
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            ReadingProgressIndicator(currentPage: 127, totalPages: 354, width: 150)
            ReadingProgressIndicator(currentPage: 0, totalPages: 280, width: 150)
            ReadingProgressIndicator(currentPage: 280, totalPages: 280, width: 150)
        }
        .padding()
    }
}