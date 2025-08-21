import SwiftUI

// MARK: - Session Timeline Card
struct SessionTimelineCard: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    let isExpanded: Bool
    let onTap: () -> Void
    let onContinue: () -> Void
    let onViewDetail: () -> Void
    
    @State private var isPressed = false
    
    private var bookTitle: String {
        session.bookModel?.title ?? "Unknown Book"
    }
    
    private var keyInsight: String {
        // Generate a key insight from the session
        if let firstQuestion = session.capturedQuestions.first {
            return firstQuestion.content
        } else if let firstQuote = session.capturedQuotes.first {
            return "\"\(firstQuote.text)\""
        } else if let firstNote = session.capturedNotes.first {
            return firstNote.content
        }
        return "Reading session"
    }
    
    private var sessionMetrics: (duration: String, questions: Int, quotes: Int, notes: Int) {
        let duration = session.duration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        let durationString = if hours > 0 {
            "\(hours)h \(minutes)m"
        } else {
            "\(minutes)m"
        }
        
        return (
            duration: durationString,
            questions: session.capturedQuestions.count,
            quotes: session.capturedQuotes.count,
            notes: session.capturedNotes.count
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main card content
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bookTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text(session.startTime.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    // Metrics badges
                    HStack(spacing: 8) {
                        if sessionMetrics.questions > 0 {
                            MetricBadge(
                                icon: "questionmark.circle",
                                value: sessionMetrics.questions,
                                color: .blue
                            )
                        }
                        if sessionMetrics.quotes > 0 {
                            MetricBadge(
                                icon: "quote.bubble",
                                value: sessionMetrics.quotes,
                                color: .green
                            )
                        }
                        if sessionMetrics.notes > 0 {
                            MetricBadge(
                                icon: "note.text",
                                value: sessionMetrics.notes,
                                color: .orange
                            )
                        }
                    }
                }
                
                // Key insight preview
                Text(keyInsight)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Duration
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(sessionMetrics.duration)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
            
            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .background(.white.opacity(0.1))
                    
                    HStack(spacing: 12) {
                        // Continue button
                        Button {
                            HapticManager.shared.mediumTap()
                            onContinue()
                        } label: {
                            Label("Continue", systemImage: "arrow.right.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.white.opacity(0.1))
                                }
                        }
                        
                        // View details button
                        Button {
                            HapticManager.shared.lightTap()
                            onViewDetail()
                        } label: {
                            Label("View", systemImage: "doc.text")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.white.opacity(0.1))
                                }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background {
            // Use colorPalette for subtle gradient if available
            if let palette = colorPalette {
                LinearGradient(
                    colors: [
                        palette.primary.opacity(0.15),
                        palette.secondary.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPressed)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
        .onTapGesture {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isPressed = true
            }
            HapticManager.shared.lightTap()
            onTap()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Metric Badge
struct MetricBadge: View {
    let icon: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text("\(value)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(color.opacity(0.15))
        }
    }
}