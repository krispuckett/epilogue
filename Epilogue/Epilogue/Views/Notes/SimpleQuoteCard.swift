import SwiftUI

// MARK: - Simple Quote Card for Award Winning Notes View
struct SimpleQuoteCard: View {
    let note: Note
    @Environment(\.sizeCategory) var sizeCategory
    @State private var isPressed = false
    
    var firstLetter: String {
        String(note.content.prefix(1))
    }
    
    var restOfContent: String {
        String(note.content.dropFirst())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Large transparent opening quote
            Text("\u{201C}")
                .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 60 : 80))
                .foregroundStyle(Color.white.opacity(0.15))
                .offset(x: -10, y: 20)
                .frame(height: 0)
                .accessibilityHidden(true)
            
            // Quote content with drop cap
            HStack(alignment: .top, spacing: 0) {
                // Drop cap
                Text(firstLetter)
                    .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 70 : 56))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .padding(.trailing, 4)
                    .offset(y: -8)
                
                // Rest of quote
                Text(restOfContent)
                    .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 30 : 24))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .lineSpacing(sizeCategory.isAccessibilitySize ? 14 : 11)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.top, 20)
            
            // Attribution section
            VStack(alignment: .leading, spacing: 16) {
                // Thin horizontal rule with gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 0),
                        .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(1.0), location: 0.5),
                        .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.top, 28)
                
                // Book and author info
                VStack(alignment: .leading, spacing: 8) {
                    if let bookTitle = note.bookTitle {
                        Text(bookTitle)
                            .font(.custom("Georgia-Italic", size: sizeCategory.isAccessibilitySize ? 18 : 15))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.9))
                    }
                    
                    if let author = note.author {
                        Text("— \(author)")
                            .font(.system(size: sizeCategory.isAccessibilitySize ? 16 : 13, weight: .medium))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                    }
                    
                    if let pageNumber = note.pageNumber {
                        Text("Page \(pageNumber)")
                            .font(.system(size: sizeCategory.isAccessibilitySize ? 14 : 11))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                    }
                }
                .padding(.bottom, 4)
            }
            
            // Large closing quote at bottom right
            HStack {
                Spacer()
                Text("\u{201D}")
                    .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 60 : 80))
                    .foregroundStyle(Color.white.opacity(0.15))
                    .offset(x: 10, y: -20)
                    .accessibilityHidden(true)
            }
            .frame(height: 0)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.15, green: 0.14, blue: 0.13),
                            Color(red: 0.12, green: 0.11, blue: 0.10)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.2),
                                    Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.05)
                                ]),
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
}