import SwiftUI

// MARK: - Session Book Card (Horizontal Scroll)
struct SessionBookCard: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    let onContinue: () -> Void
    let onViewDetail: () -> Void
    
    @State private var isPressed = false
    
    private var sessionDate: String {
        session.startTime.formatted(date: .abbreviated, time: .omitted)
    }
    
    private var sessionTime: String {
        session.startTime.formatted(date: .omitted, time: .shortened)
    }
    
    private var contentSummary: String {
        let counts = [
            session.capturedQuestions.count > 0 ? "\(session.capturedQuestions.count) questions" : nil,
            session.capturedQuotes.count > 0 ? "\(session.capturedQuotes.count) quotes" : nil,
            session.capturedNotes.count > 0 ? "\(session.capturedNotes.count) notes" : nil
        ].compactMap { $0 }
        
        return counts.isEmpty ? "Empty session" : counts.joined(separator: " · ")
    }
    
    private var keyTopic: String? {
        // Extract the most interesting question or quote
        if let question = session.capturedQuestions.first {
            return question.content
        } else if let quote = session.capturedQuotes.first {
            return "\"\(quote.text)\""
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Content area
            VStack(alignment: .leading, spacing: 12) {
                // Date and time
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionDate)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(sessionTime)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                // Key topic preview
                if let keyTopic = keyTopic {
                    Text(keyTopic)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 8)
                
                // Content summary
                Text(contentSummary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.inlinePadding)
            .frame(width: 200, height: 140)
            
            // Action buttons
            HStack(spacing: 0) {
                Button {
                    SensoryFeedback.light()
                    onViewDetail()
                } label: {
                    Text("View")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                
                Divider()
                    .background(.white.opacity(0.1))
                    .frame(height: 20)
                
                Button {
                    SensoryFeedback.medium()
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .background(.white.opacity(0.05))
        }
        .background {
            if let palette = colorPalette {
                // Subtle gradient based on book colors
                LinearGradient(
                    colors: [
                        palette.primary.opacity(0.2),
                        palette.secondary.opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
        .onTapGesture {
            withAnimation(DesignSystem.Animation.springQuick) {
                isPressed = true
            }
            SensoryFeedback.light()
            onViewDetail()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignSystem.Animation.springQuick) {
                    isPressed = false
                }
            }
        }
    }
}