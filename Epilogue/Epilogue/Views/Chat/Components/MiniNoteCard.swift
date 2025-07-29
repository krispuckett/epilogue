import SwiftUI

// MARK: - Mini Note Card for Chat

struct MiniNoteCard: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text("Note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(note.timestamp, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                // Content preview (2 lines max)
                Text(note.content)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Book context if available
                if let book = note.book {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Text(book.title)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                        
                        if let pageNumber = note.pageNumber {
                            Text("• p.\(pageNumber)")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Mini Quote Card for Chat

struct MiniQuoteCard: View {
    let quote: Quote
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Small quotation mark
                Text("\u{201C}")
                    .font(.custom("Georgia", size: 24))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                    .frame(height: 12)
                    .offset(y: 4)
                
                // Quote preview (truncated)
                Text(quote.text)
                    .font(.custom("Georgia", size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // Attribution
                VStack(alignment: .leading, spacing: 2) {
                    if let book = quote.book {
                        Text("— \(quote.author ?? book.author)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        HStack(spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineLimit(1)
                            
                            if let pageNumber = quote.pageNumber {
                                Text("• p.\(pageNumber)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 16) {
            // Mock Note
            MiniNoteCard(
                note: Note(
                    content: "This is an interesting observation about the protagonist's character development throughout the chapter. The way they handle conflict has evolved significantly.",
                    book: BookModel(
                        id: "1",
                        title: "The Great Gatsby",
                        author: "F. Scott Fitzgerald"
                    ),
                    pageNumber: 42
                ),
                onTap: {}
            )
            .frame(maxWidth: 300)
            
            // Mock Quote
            MiniQuoteCard(
                quote: Quote(
                    text: "So we beat on, boats against the current, borne back ceaselessly into the past.",
                    book: BookModel(
                        id: "1",
                        title: "The Great Gatsby",
                        author: "F. Scott Fitzgerald"
                    ),
                    pageNumber: 180
                ),
                onTap: {}
            )
            .frame(maxWidth: 300)
        }
        .padding()
    }
}