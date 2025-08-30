import SwiftUI

struct SessionSummaryView: View {
    let session: ProcessedAmbientSession
    let onDismiss: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        ZStack {
            // Dark background matching app aesthetic
            DesignSystem.Colors.surfaceBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header card with glass effect
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("READING SESSION")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .kerning(1.5)
                                    .foregroundStyle(Color.warmAmber.opacity(0.8))
                                
                                Text("Session Complete")
                                    .font(.custom("Georgia", size: 28))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                            }
                            
                            Spacer()
                            
                            Button(action: onDismiss) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                            }
                        }
                        
                        // Duration
                        HStack {
                            Image(systemName: "clock")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                            Text(session.formattedDuration)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                            Spacer()
                        }
                    }
                    .padding(DesignSystem.Spacing.cardPadding)
                    .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
                    
                    // Stats row
                    HStack(spacing: 16) {
                        StatCard(
                            icon: "quote.bubble.fill",
                            count: session.quotes.count,
                            label: "Quotes"
                        )
                        
                        StatCard(
                            icon: "note.text",
                            count: session.notes.count,
                            label: "Notes"
                        )
                        
                        StatCard(
                            icon: "questionmark.circle.fill",
                            count: session.questions.count,
                            label: "Questions"
                        )
                    }
                    
                    // Summary card
                    if !session.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUMMARY")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .kerning(1.2)
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                            
                            Text(session.summary)
                                .font(.custom("SF Pro Display", size: 16))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.9))
                                .lineSpacing(4)
                        }
                        .padding(DesignSystem.Spacing.listItemPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }
                    }
                    
                    // Show all captured items as cards in chronological order
                    SessionContentCardsView(
                        session: session,
                        bookTitle: extractBookTitle(from: session.summary),
                        bookAuthor: extractBookAuthor(from: session.summary)
                    )
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: onViewDetails) {
                            Text("View Full Session")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.warmAmber)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                        }
                        
                        Button(action: onDismiss) {
                            Text("Done")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(DesignSystem.Spacing.listItemPadding)
            }
        }
    }
    
    // Helper functions to extract book info from summary
    private func extractBookTitle(from summary: String) -> String? {
        // Look for pattern like "Reading session with [Book Title]"
        if summary.contains("with") {
            let parts = summary.split(separator: "with")
            if parts.count > 1 {
                let bookPart = parts[1].trimmingCharacters(in: .whitespaces)
                // Remove any trailing periods or other punctuation
                return String(bookPart.split(separator: ".").first ?? "")
            }
        }
        return nil
    }
    
    private func extractBookAuthor(from summary: String) -> String? {
        // For now, return nil as author might not be in summary
        // Could be enhanced to extract from session data
        return nil
    }
}

// Updated StatCard to match note card styling
struct StatCard: View {
    let icon: String
    let count: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.warmAmber.opacity(0.8))
            
            Text("\(count)")
                .font(.custom("Georgia", size: 28))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
            
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .kerning(1.0)
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.4)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        }
    }
}

// Transcript note card matching the screenshot style
struct TranscriptNoteCard: View {
    let type: String
    let content: String
    let bookTitle: String?
    let timestamp: Date
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: timestamp)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with date and type icon
            HStack {
                Text(formattedDate.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                
                Spacer()
                
                Image(systemName: type == "QUESTION" ? "questionmark.circle" : "note.text")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.warmAmber.opacity(0.6))
            }
            
            // Content
            Text(content)
                .font(.custom("SF Pro Display", size: 18))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
            
            // Book reference
            if let bookTitle = bookTitle, !bookTitle.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 0),
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.3), location: 0.5),
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 0.5)
                    .padding(.top, 8)
                    
                    HStack(spacing: 8) {
                        Text("re:")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                        
                        Text(bookTitle)
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.cardPadding)
        .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

// Transcript quote card with literary styling
struct TranscriptQuoteCard: View {
    let quote: String
    let bookTitle: String?
    let timestamp: Date
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: timestamp)
    }
    
    var firstLetter: String {
        String(quote.prefix(1))
    }
    
    var restOfContent: String {
        String(quote.dropFirst())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date in corner
            HStack {
                Spacer()
                Text(formattedDate.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.3))
            }
            .padding(.bottom, 8)
            
            // Large transparent opening quote
            Text("\u{201C}")
                .font(.custom("Georgia", size: 80))
                .foregroundStyle(Color.warmAmber.opacity(0.8))
                .offset(x: -10, y: 20)
                .frame(height: 0)
            
            // Quote content with drop cap
            HStack(alignment: .top, spacing: 0) {
                // Drop cap
                Text(firstLetter)
                    .font(.custom("Georgia", size: 48))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .padding(.trailing, 4)
                    .offset(y: -6)
                
                // Rest of quote
                Text(restOfContent)
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            .padding(.top, 16)
            
            // Attribution
            if let bookTitle = bookTitle {
                VStack(alignment: .leading, spacing: 8) {
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
                    .padding(.top, 16)
                    
                    Text(bookTitle.uppercased())
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .kerning(1.5)
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.7))
                }
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.surfaceBackground)
        )
        .shadow(color: Color(red: 0.8, green: 0.7, blue: 0.6).opacity(0.15), radius: 12, x: 0, y: 4)
    }
}