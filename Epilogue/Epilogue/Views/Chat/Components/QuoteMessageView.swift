import SwiftUI

struct QuoteMessageView: View {
    let quote: ExtractedQuote
    let book: Book?
    let isUser: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quote content with elegant styling
            VStack(alignment: .leading, spacing: 4) {
                // Opening quote mark
                Text("\u{201C}")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.primary.opacity(0.3))
                    .offset(x: -8, y: 8)
                
                // Quote text
                Text(quote.text)
                    .font(.custom("Georgia", size: 18))
                    .italic()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                
                // Closing quote mark
                HStack {
                    Spacer()
                    Text("\u{201D}")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.primary.opacity(0.3))
                        .offset(x: 8, y: -8)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            
            // Attribution and saved indicator
            if book != nil {
                HStack(spacing: 12) {
                    // Book cover thumbnail
                    if let coverURL = book?.coverImageURL {
                        SharedBookCoverView(
                            coverURL: coverURL,
                            width: 20,
                            height: 28
                        )
                        .shadow(radius: 2)
                    }
                    
                    // Book title
                    if let title = book?.title {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Saved indicator
                    Label("Saved to Quotes", systemImage: "bookmark.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal, isUser ? 40 : 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        QuoteMessageView(
            quote: ExtractedQuote(
                text: "Not all those who wander are lost.",
                context: "The Lord of the Rings",
                timestamp: Date()
            ),
            book: nil,
            isUser: true
        )
        
        QuoteMessageView(
            quote: ExtractedQuote(
                text: "It is our choices, Harry, that show what we truly are, far more than our abilities.",
                context: "Harry Potter",
                timestamp: Date()
            ),
            book: nil,
            isUser: false
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}