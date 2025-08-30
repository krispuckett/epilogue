import SwiftUI

struct NoteMessageView: View {
    let note: ExtractedNote
    let book: Book?
    let isUser: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Note content with appropriate styling
            VStack(alignment: .leading, spacing: 12) {
                // Note type indicator
                HStack {
                    Image(systemName: note.type.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(note.type.color)
                    
                    Text(note.type.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(note.type.color)
                    
                    Spacer()
                }
                
                // Note text
                Text(note.text)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(note.type.backgroundColor.opacity(0.1))
            .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
            
            // Attribution and saved indicator
            HStack(spacing: 12) {
                // Book info if available
                if let book = book {
                    if let coverURL = book.coverImageURL {
                        SharedBookCoverView(
                            coverURL: coverURL,
                            width: 16,
                            height: 22
                        )
                        .shadow(radius: 1)
                    }
                    
                    Text(book.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Saved indicator
                Label("Saved to Notes", systemImage: "note.text")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, isUser ? 40 : 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Note Type Extensions
extension ExtractedNote.NoteType {
    var displayName: String {
        switch self {
        case .reflection:
            return "Reflection"
        case .insight:
            return "Insight"
        case .connection:
            return "Connection"
        }
    }
    
    var iconName: String {
        switch self {
        case .reflection:
            return "bubble.left"
        case .insight:
            return "lightbulb"
        case .connection:
            return "link"
        }
    }
    
    var color: Color {
        switch self {
        case .reflection:
            return .blue
        case .insight:
            return .yellow
        case .connection:
            return .purple
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .reflection:
            return .blue
        case .insight:
            return .yellow
        case .connection:
            return .purple
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        NoteMessageView(
            note: ExtractedNote(
                text: "This chapter reminds me of my own journey learning to code. The struggle and eventual breakthrough feel so similar.",
                type: .connection,
                timestamp: Date()
            ),
            book: nil,
            isUser: true
        )
        
        NoteMessageView(
            note: ExtractedNote(
                text: "I realize now that the author is using water as a metaphor for memory throughout the entire novel.",
                type: .insight,
                timestamp: Date()
            ),
            book: nil,
            isUser: false
        )
        
        NoteMessageView(
            note: ExtractedNote(
                text: "The way the character handles grief is making me think about my own experiences differently.",
                type: .reflection,
                timestamp: Date()
            ),
            book: nil,
            isUser: true
        )
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}