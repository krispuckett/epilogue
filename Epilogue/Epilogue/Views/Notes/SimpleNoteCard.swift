import SwiftUI

// MARK: - Simple Note Card for Award Winning Notes View
struct SimpleNoteCard: View {
    let note: Note
    @Environment(\.sizeCategory) var sizeCategory
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with metadata
            HStack {
                if let bookTitle = note.bookTitle {
                    Label(bookTitle, systemImage: "book.closed.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(note.dateCreated, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
            }
            
            // Main content
            Text(note.content)
                .font(.system(size: sizeCategory.isAccessibilitySize ? 18 : 15, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                .lineSpacing(sizeCategory.isAccessibilitySize ? 8 : 6)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: false)
            
            // Footer with tags or actions
            if let pageNumber = note.pageNumber {
                HStack {
                    Image(systemName: "bookmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                    
                    Text("Page \(pageNumber)")
                        .font(.system(size: 11))
                        .foregroundStyle(.gray)
                    
                    Spacer()
                    
                    // Note type indicator
                    noteTypeIndicator
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.2 : 0.1),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            // Handle tap
        }
        .pressEvents(onPress: {
            withAnimation(.spring(response: 0.1)) {
                isPressed = true
            }
        }, onRelease: {
            withAnimation(.spring(response: 0.1)) {
                isPressed = false
            }
        })
    }
    
    @ViewBuilder
    private var noteTypeIndicator: some View {
        switch note.type {
        case .note:
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                Text("Note")
            }
            .font(.system(size: 10))
            .foregroundStyle(.blue.opacity(0.8))
        case .quote:
            HStack(spacing: 4) {
                Image(systemName: "quote.bubble")
                Text("Quote")
            }
            .font(.system(size: 10))
            .foregroundStyle(.yellow.opacity(0.8))
        }
    }
}

// Press events already defined in HeroTransitionView