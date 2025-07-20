import SwiftUI

struct LitBookCover: View {
    let book: Book
    @StateObject private var motionManager = MotionManager()
    @State private var isHovered = false
    
    var lightPosition: CGPoint {
        motionManager.lightPosition
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base book cover
                SharedBookCoverView(coverURL: book.coverImageURL)
                
                // Simulated room light reflection
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            center: UnitPoint(x: lightPosition.x, y: lightPosition.y),
                            startRadius: 0,
                            endRadius: 0.8
                        )
                    )
                    .blendMode(.overlay)
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8), value: lightPosition)
                
                // Specular highlight that follows motion
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .blur(radius: 15)
                    .position(
                        x: lightPosition.x * geometry.size.width,
                        y: lightPosition.y * geometry.size.height
                    )
                    .blendMode(.screen)
                    .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.8), value: lightPosition)
                
                // Additional rim lighting based on tilt
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3 + abs(motionManager.normalizedTiltX) * 0.3),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: motionManager.normalizedTiltX > 0 ? .leading : .trailing,
                            endPoint: motionManager.normalizedTiltX > 0 ? .trailing : .leading
                        ),
                        lineWidth: 2
                    )
                    .blendMode(.overlay)
                    .animation(.easeOut(duration: 0.3), value: motionManager.normalizedTiltX)
                
                // Hover effect for desktop
                if isHovered {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .blendMode(.overlay)
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .aspectRatio(2/3, contentMode: .fit)
        .shadow(
            color: .black.opacity(0.3 + abs(motionManager.normalizedTiltY) * 0.2),
            radius: 10 + abs(motionManager.normalizedTiltY) * 5,
            x: motionManager.normalizedTiltX * 10,
            y: 5 + motionManager.normalizedTiltY * 5
        )
    }
}


// Preview
struct LitBookCover_Previews: PreviewProvider {
    static var previews: some View {
        LitBookCover(book: Book(
            id: "1",
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            publishedYear: "1925",
            coverImageURL: nil
        ))
        .frame(width: 200, height: 300)
        .padding()
    }
}