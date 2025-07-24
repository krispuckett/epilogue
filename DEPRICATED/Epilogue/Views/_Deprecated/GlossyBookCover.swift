import SwiftUI

struct GlossyBookCover: View {
    let book: Book
    @State private var dragLocation: CGPoint = .zero
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base book cover
                SharedBookCoverView(coverURL: book.coverImageURL)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Glossy overlay with interactive lighting
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(isDragging ? 0.5 : 0.3),
                                Color.white.opacity(isDragging ? 0.2 : 0.1),
                                Color.clear
                            ],
                            center: UnitPoint(
                                x: dragLocation.x / geometry.size.width,
                                y: dragLocation.y / geometry.size.height
                            ),
                            startRadius: isDragging ? 20 : 50,
                            endRadius: isDragging ? 150 : 100
                        )
                    )
                    .blendMode(.overlay)
                    .allowsHitTesting(false)
                
                // Specular highlight
                Circle()
                    .fill(Color.white.opacity(isDragging ? 0.8 : 0.4))
                    .frame(width: isDragging ? 40 : 20, height: isDragging ? 40 : 20)
                    .blur(radius: isDragging ? 20 : 10)
                    .position(dragLocation)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.2), value: isDragging)
                
                // Edge shine effect
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.overlay)
            }
            .onAppear {
                dragLocation = CGPoint(
                    x: geometry.size.width * 0.7,
                    y: geometry.size.height * 0.3
                )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragLocation = value.location
                        isDragging = true
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .aspectRatio(2/3, contentMode: .fit)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// Preview
struct GlossyBookCover_Previews: PreviewProvider {
    static var previews: some View {
        GlossyBookCover(book: Book(
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