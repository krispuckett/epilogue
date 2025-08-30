import SwiftUI

// MARK: - Simple Note Card for Award Winning Notes View
struct SimpleNoteCard: View {
    let note: Note
    @Environment(\.sizeCategory) var sizeCategory
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Date
                Text(note.formattedDate)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                
                Spacer()
                
                // Note indicator
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white.opacity(0.2))
            }
            
            // Content
            Text(note.content)
                .font(.custom("SF Pro Display", size: 16))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            // Book info (if available)
            if note.bookTitle != nil || note.author != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1))
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 8) {
                        Text("re:")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let bookTitle = note.bookTitle {
                                Text(bookTitle)
                                    .font(.system(size: 14, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.9))
                            }
                            
                            HStack(spacing: 8) {
                                if let author = note.author {
                                    Text(author)
                                        .font(.system(size: 12, design: .default))
                                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                                }
                                
                                if let pageNumber = note.pageNumber {
                                    Text("• p. \(pageNumber)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
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
    
}

// Press events already defined in HeroTransitionView