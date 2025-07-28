import SwiftUI

struct BookContextPill: View {
    let book: Book?
    let onTap: () -> Void
    
    @State private var isPressed = false
    @State private var isAnimatingIn = false
    @Environment(\.colorScheme) var colorScheme
    
    // Reading progress calculated from book model
    private var readingProgress: Double? {
        // Calculate reading progress from currentPage and pageCount
        if let book = book, 
           let pageCount = book.pageCount, 
           pageCount > 0,
           book.currentPage > 0 {
            return Double(book.currentPage) / Double(pageCount)
        }
        return nil
    }
    
    var body: some View {
        if let book = book {
            activeContextPill(book: book)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
        } else {
            emptyContextPill
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
        }
    }
    
    // MARK: - Active Context Pill
    
    private func activeContextPill(book: Book) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Mini book cover
                if let coverURL = book.coverImageURL {
                    SharedBookCoverView(
                        coverURL: coverURL,
                        width: 16,
                        height: 24
                    )
                    .cornerRadius(2)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                } else {
                    // Placeholder cover
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))
                        .frame(width: 16, height: 24)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                }
                
                // Book info
                VStack(alignment: .leading, spacing: 1) {
                    Text(book.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    HStack(spacing: 4) {
                        Text(book.author)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        // Reading progress indicator
                        if let progress = readingProgress {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                            
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: 200, alignment: .leading)
                
                // Chevron indicator
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .rotationEffect(.degrees(isPressed ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .scaleEffect(isAnimatingIn ? 1.0 : 0.9)
            .opacity(isAnimatingIn ? 1.0 : 0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAnimatingIn = true
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Long press to show book info/history (future feature)
            HapticManager.shared.mediumTap()
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        }
    }
    
    // MARK: - Empty Context Pill
    
    private var emptyContextPill: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                
                Text("Select a book")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .scaleEffect(isAnimatingIn ? 1.0 : 0.9)
            .opacity(isAnimatingIn ? 1.0 : 0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isAnimatingIn = true
            }
        }
        .onLongPressGesture(minimumDuration: 0) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPressed = true
            }
        } onPressingChanged: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Container with Animation Support

struct AnimatedBookContextPill: View {
    let book: Book?
    let onTap: () -> Void
    @Namespace private var animation
    
    var body: some View {
        BookContextPill(book: book, onTap: onTap)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: book?.localId)
    }
}

// MARK: - Preview

#Preview("With Book") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            BookContextPill(
                book: Book(
                    id: "preview-1",
                    title: "The Memory Palace: A Very Long Title That Should Truncate",
                    author: "John Doe with a Very Long Author Name",
                    coverImageURL: nil
                ),
                onTap: {}
            )
            .padding()
            
            Spacer()
        }
    }
}

#Preview("Empty State") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            BookContextPill(
                book: nil,
                onTap: {}
            )
            .padding()
            
            Spacer()
        }
    }
}