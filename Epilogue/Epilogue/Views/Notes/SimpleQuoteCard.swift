import SwiftUI

// MARK: - Simple Quote Card for Award Winning Notes View
struct SimpleQuoteCard: View {
    let note: Note
    let capturedQuote: CapturedQuote?
    @Environment(\.sizeCategory) var sizeCategory
    @State private var isPressed = false
    @State private var showDate = false
    @State private var showingSessionSummary = false
    
    // Convenience initializer for backward compatibility
    init(note: Note, capturedQuote: CapturedQuote? = nil) {
        self.note = note
        self.capturedQuote = capturedQuote
    }
    
    var firstLetter: String {
        String(note.content.prefix(1)).uppercased()
    }
    
    var restOfContent: String {
        String(note.content.dropFirst())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Date header (shown on tap)
            if showDate {
                HStack {
                    Text(formatDate(note.dateCreated).uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .kerning(1.2)
                        .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.6))
                    
                    Spacer()
                    
                    // Session pill for ambient quotes
                    if let session = capturedQuote?.ambientSession,
                       let source = capturedQuote?.source as? String,
                       source == "ambient" {
                        Button {
                            showingSessionSummary = true
                            SensoryFeedback.light()
                        } label: {
                            HStack(spacing: 6) {
                                Text("SESSION")
                                    .font(.system(size: 10, weight: .semibold, design: .default))
                                    .kerning(1.0)

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(DesignSystem.Colors.primaryAccent.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                    .stroke(DesignSystem.Colors.primaryAccent.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.bottom, 16)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Large transparent opening quote - subtle amber
            Text("\u{201C}")
                .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 60 : 80))
                .foregroundStyle(DesignSystem.Colors.primaryAccent.opacity(0.3))
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
                    .lineSpacing(sizeCategory.isAccessibilitySize ? 14 : 11) // Line height 1.5
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
                
                // Attribution text - reordered: Author -> Source -> Page
                VStack(alignment: .leading, spacing: 8) {
                    if let author = note.author {
                        Text(author.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                    }
                    
                    if let bookTitle = note.bookTitle {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                            .padding(.bottom, 2) // Add a bit more space before page number
                    }
                    
                    if let pageNumber = note.pageNumber {
                        Text("PAGE \(pageNumber)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                    }
                }
            }
        }
        .padding(32) // Generous padding
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
        .animation(DesignSystem.Animation.springStandard, value: showDate)
        .onTapGesture {
            withAnimation(DesignSystem.Animation.springStandard) {
                showDate.toggle()
            }
            SensoryFeedback.light()
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
        .sheet(isPresented: $showingSessionSummary) {
            if let session = capturedQuote?.ambientSession {
                NavigationStack {
                    AmbientSessionSummaryView(session: session, colorPalette: nil)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}