import SwiftUI

// MARK: - Ambient Session Summary View
struct AmbientSessionSummaryView: View {
    let session: ProcessedAmbientSession
    let bookTitle: String?
    let onContinueToChat: () -> Void
    let onDiscardSession: () -> Void
    @State private var showDetails = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Enhanced amber gradient background
            EnhancedAmberGradient(
                phase: 0.5,
                audioLevel: 0,
                isListening: false,
                voiceFrequency: 0.5,
                voiceIntensity: 0.0,
                voiceRhythm: 0.0
            )
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        Text("Session Complete")
                            .font(.system(size: 28, weight: .medium, design: .serif))
                            .foregroundStyle(.white.opacity(0.9))
                        
                        if let bookTitle = bookTitle {
                            Text(bookTitle)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        
                        Text(session.formattedDuration)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.orange.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 40)
                    
                    // Captured Items Summary
                    VStack(spacing: 16) {
                        SummaryCard(
                            icon: "quote.bubble.fill",
                            title: "Quotes",
                            count: session.quotes.count,
                            color: .blue,
                            items: session.quotes.map { $0.text }
                        )
                        
                        SummaryCard(
                            icon: "lightbulb.fill",
                            title: "Notes",
                            count: session.notes.count,
                            color: .green,
                            items: session.notes.map { $0.text }
                        )
                        
                        SummaryCard(
                            icon: "questionmark.circle.fill",
                            title: "Questions",
                            count: session.questions.count,
                            color: .orange,
                            items: session.questions.map { $0.text }
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Session Summary
                    if !session.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Session Summary")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Text(session.summary)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        // Continue to Chat Button
                        Button {
                            onContinueToChat()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 18))
                                Text("Continue to Chat")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassEffect(.regular.tint(Color.orange.opacity(0.3)), in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                            }
                        }
                        
                        // Discard Session Button
                        Button {
                            onDiscardSession()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                Text("Discard Session")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    let items: [String]
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Card Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showDetails.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(color.opacity(0.2))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        
                        Text("\(count) captured")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    if count > 0 {
                        Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(16)
            }
            .disabled(count == 0)
            
            // Expandable Details
            if showDetails && !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(color.opacity(0.6))
                                .frame(width: 4, height: 4)
                                .padding(.top, 8)
                            
                            Text(item)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    if items.count > 3 {
                        Text("+ \(items.count - 3) more...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(color.opacity(0.8))
                            .padding(.top, 4)
                            .padding(.leading, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            color.opacity(0.3),
                            color.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
    }
}

#Preview {
    AmbientSessionSummaryView(
        session: ProcessedAmbientSession(
            quotes: [
                ExtractedQuote(text: "To be or not to be, that is the question", context: "Hamlet", timestamp: Date()),
                ExtractedQuote(text: "All the world's a stage", context: "As You Like It", timestamp: Date())
            ],
            notes: [
                ExtractedNote(text: "This reminds me of Socratic questioning", type: .reflection, timestamp: Date()),
                ExtractedNote(text: "The author's use of metaphor here is brilliant", type: .insight, timestamp: Date())
            ],
            questions: [
                ExtractedQuestion(text: "What does this say about human nature?", context: "Hamlet", timestamp: Date())
            ],
            summary: "A thoughtful session exploring existential themes in Shakespeare's works, with particular focus on questions of identity and purpose.",
            duration: 185.0
        ),
        bookTitle: "Hamlet"
    ) {
        print("Continue to chat")
    } onDiscardSession: {
        print("Discard session")
    }
    .preferredColorScheme(.dark)
}