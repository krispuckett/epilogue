import SwiftUI

struct ProgressiveSessionSummaryView: View {
    let session: ProcessedAmbientSession
    let bookTitle: String?
    @State private var isExpanded = false
    @Namespace private var animation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Collapsed Summary Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let title = bookTitle {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 12) {
                        Label(session.formattedDuration, systemImage: "clock")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        Text("•")
                            .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 11))
                            Text("\(session.quotes.count)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                            Text("\(session.notes.count)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                            Text("\(session.questions.count)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                        SensoryFeedback.light()
                    }
                } label: {
                    Text(isExpanded ? "Hide Details" : "View Details")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.warmAmber)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6))
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
            
            // Expanded Details
            if isExpanded {
                VStack(alignment: .leading, spacing: 20) {
                    // Questions Preview (First 3)
                    if !session.questions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Questions", systemImage: "questionmark.circle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            
                            ForEach(session.questions.prefix(3), id: \.text) { question in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(question.text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.8))
                                    
                                    // AI Response Preview (if available)
                                    Text("Epilogue will help explore this question...")
                                        .font(.system(size: 13))
                                        .italic()
                                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                                        .lineLimit(2)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                            
                            if session.questions.count > 3 {
                                Text("+ \(session.questions.count - 3) more questions")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                    
                    // Quotes Preview (First 2)
                    if !session.quotes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Quotes", systemImage: "quote.opening")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            
                            ForEach(session.quotes.prefix(2), id: \.text) { quote in
                                Text("\"\(quote.text)\"")
                                    .font(.system(size: 14))
                                    .italic()
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                            }
                            
                            if session.quotes.count > 2 {
                                Text("+ \(session.quotes.count - 2) more quotes")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                    
                    // View Full Transcript Button
                    Button {
                        SensoryFeedback.light()
                        // Navigate to full transcript
                    } label: {
                        HStack {
                            Text("View Full Transcript")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color.warmAmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.warmAmber.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
}