import SwiftUI

// MARK: - Mini Note Card for Chat

struct MiniNoteCard: View {
    let note: CapturedNote
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text("Note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text(note.timestamp ?? Date(), style: .time)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                // Content
                Text(note.content ?? "")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                
                // Book context if available
                if let book = note.book {
                    HStack(spacing: 4) {
                        Text("re:")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        
                        Text(book.title)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                            .textCase(.uppercase)
                        
                        if let pageNumber = note.pageNumber {
                            Text("• PAGE \(pageNumber)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                                .textCase(.uppercase)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
}

// MARK: - Mini Quote Card for Chat

struct MiniQuoteCard: View {
    let quote: CapturedQuote
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // Small quotation mark like original design
                Text("\u{201C}")
                    .font(.custom("Georgia", size: 36))
                    .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.4))
                    .frame(height: 16)
                    .offset(y: 8)
                
                // Quote text - mini version of original
                Text(quote.text ?? "")
                    .font(.custom("Georgia", size: 14))
                    .italic()
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
                
                // Attribution
                VStack(alignment: .leading, spacing: 4) {
                    if let author = quote.author ?? quote.book?.author {
                        Text("— \(author)")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.8))
                    }
                    
                    if let book = quote.book {
                        HStack(spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                                .textCase(.uppercase)
                            
                            if let pageNumber = quote.pageNumber {
                                Text("• PAGE \(pageNumber)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .textCase(.uppercase)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.2), lineWidth: 0.5)
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
                note: CapturedNote(
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
                quote: CapturedQuote(
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