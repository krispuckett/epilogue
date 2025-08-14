import SwiftUI
import SwiftData

// MARK: - Ambient Session Summary View
struct AmbientSessionSummaryView: View {
    let session: AmbientSession
    let colorPalette: ColorPalette?
    @State private var expandedCards = Set<String>()
    @State private var showFullTranscript = false
    @State private var continuationText = ""
    @State private var selectedThread: ConversationThread?
    @FocusState private var isInputFocused: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    // Animation states
    @State private var cardsVisible = false
    @State private var headerExpanded = false
    
    var body: some View {
        ZStack {
            // Gradient background - using existing system
            if let palette = colorPalette {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 0.7,
                    audioLevel: 0
                )
                .ignoresSafeArea()
            } else {
                AmbientChatGradientView()
                    .ignoresSafeArea()
            }
            
            // Main content
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // Session header card
                        SessionHeaderCard(
                            session: session,
                            isExpanded: $headerExpanded,
                            colorPalette: colorPalette
                        )
                        .padding(.top, 60)
                        
                        // Grouped conversation threads
                        ForEach(session.groupedThreads) { thread in
                            ConversationThreadCard(
                                thread: thread,
                                isExpanded: expandedCards.contains(thread.id),
                                colorPalette: colorPalette,
                                onToggle: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if expandedCards.contains(thread.id) {
                                            expandedCards.remove(thread.id)
                                        } else {
                                            expandedCards.insert(thread.id)
                                        }
                                    }
                                },
                                onSelectFollowUp: { question in
                                    continuationText = question
                                    isInputFocused = true
                                }
                            )
                            .opacity(cardsVisible ? 1 : 0)
                            .scaleEffect(cardsVisible ? 1 : 0.9)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(Double(thread.index) * 0.05),
                                value: cardsVisible
                            )
                        }
                        
                        // Captured content section
                        if !session.capturedContent.isEmpty {
                            CapturedContentSection(
                                quotes: session.quotes,
                                notes: session.notes,
                                colorPalette: colorPalette
                            )
                            .opacity(cardsVisible ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.8)
                                .delay(0.3),
                                value: cardsVisible
                            )
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                }
                .scrollIndicators(.hidden)
            }
        }
        // Navigation bar
        .overlay(alignment: .top) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .glassEffect()
                        .clipShape(Circle())
                }
                
                Spacer()
                
                SessionActionsMenu(session: session)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        // Continuation input bar
        .safeAreaInset(edge: .bottom) {
            ContinuationInputBar(
                text: $continuationText,
                isInputFocused: _isInputFocused,
                session: session,
                colorPalette: colorPalette,
                onSend: {
                    sendContinuation()
                }
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                cardsVisible = true
            }
        }
    }
    
    private func sendContinuation() {
        // Handle continuation message
        guard !continuationText.isEmpty else { return }
        
        // Process as follow-up question
        Task {
            // Implementation for processing follow-up
        }
        
        continuationText = ""
    }
}

// MARK: - Session Header Card
struct SessionHeaderCard: View {
    let session: AmbientSession
    @Binding var isExpanded: Bool
    let colorPalette: ColorPalette?
    
    @State private var statsAnimated = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                // Book icon and title
                HStack(spacing: 12) {
                    if let book = session.book {
                        if let coverURL = book.coverImageURL {
                            SharedBookCoverView(
                                coverURL: coverURL,
                                width: 40,
                                height: 60
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            
                            if let chapter = session.currentChapter {
                                Text("Chapter \(chapter)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.8))
                        
                        Text("Reading Session")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                
                Spacer()
                
                // Expand button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            
            // Quick stats row (always visible)
            HStack(spacing: 16) {
                StatPill(
                    icon: "clock",
                    value: formatDuration(session.duration),
                    animated: statsAnimated
                )
                
                StatPill(
                    icon: "questionmark.circle",
                    value: "\(session.questions.count)",
                    animated: statsAnimated
                )
                
                StatPill(
                    icon: "quote.bubble",
                    value: "\(session.quotes.count)",
                    animated: statsAnimated
                )
                
                if !session.notes.isEmpty {
                    StatPill(
                        icon: "note.text",
                        value: "\(session.notes.count)",
                        animated: statsAnimated
                    )
                }
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Key topics
                    if !session.keyTopics.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Key Topics")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                            
                            FlowLayout(spacing: 8) {
                                ForEach(session.keyTopics, id: \.self) { topic in
                                    TopicPill(topic: topic)
                                }
                            }
                        }
                    }
                    
                    // Show full transcript button
                    Button {
                        // Show full transcript
                    } label: {
                        HStack {
                            Text("Show Full Transcript")
                                .font(.system(size: 14, weight: .medium))
                            Image(systemName: "doc.text")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect()
                        .clipShape(Capsule())
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .padding(16)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                statsAnimated = true
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%dm %02ds", minutes, seconds)
    }
}

// MARK: - Conversation Thread Card
struct ConversationThreadCard: View {
    let thread: ConversationThread
    let isExpanded: Bool
    let colorPalette: ColorPalette?
    let onToggle: () -> Void
    let onSelectFollowUp: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thread header
            Button(action: onToggle) {
                HStack {
                    // Thread type icon
                    Image(systemName: thread.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(thread.iconColor)
                        .frame(width: 28, height: 28)
                        .glassEffect()
                        .clipShape(Circle())
                    
                    // Thread title (first question or topic)
                    Text(thread.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    // Message count
                    if thread.messages.count > 1 {
                        Text("\(thread.messages.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .glassEffect()
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // AI Response
                    if let response = thread.aiResponse {
                        Text(response)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Follow-up suggestions
                    if !thread.suggestedFollowUps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Follow-up questions")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                            
                            ForEach(thread.suggestedFollowUps, id: \.self) { followUp in
                                Button {
                                    onSelectFollowUp(followUp)
                                } label: {
                                    HStack {
                                        Text(followUp)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .multilineTextAlignment(.leading)
                                        
                                        Spacer()
                                        
                                        Image(systemName: "arrow.right.circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .glassEffect()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
        .padding(16)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Captured Content Section
struct CapturedContentSection: View {
    let quotes: [CapturedQuote]
    let notes: [CapturedNote]
    let colorPalette: ColorPalette?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Captured Content")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)
            
            // Quotes
            ForEach(quotes) { quote in
                QuoteSummaryCard(quote: quote, colorPalette: colorPalette)
            }
            
            // Notes
            ForEach(notes) { note in
                NoteSummaryCard(note: note, colorPalette: colorPalette)
            }
        }
    }
}

// MARK: - Quote Summary Card
struct QuoteSummaryCard: View {
    let quote: CapturedQuote
    let colorPalette: ColorPalette?
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
                
                Menu {
                    Button {
                        // Share quote
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 24, height: 24)
                }
            }
            
            Text(quote.text)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            if let author = quote.author {
                Text("— \(author)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Note Summary Card
struct NoteSummaryCard: View {
    let note: CapturedNote
    let colorPalette: ColorPalette?
    
    var body: some View {
        HStack {
            Image(systemName: "note.text")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
            
            Text(note.content)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
            
            Spacer()
        }
        .padding(12)
        .glassEffect()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Continuation Input Bar
struct ContinuationInputBar: View {
    @Binding var text: String
    @FocusState var isInputFocused: Bool
    let session: AmbientSession
    let colorPalette: ColorPalette?
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Suggested questions
            if !session.suggestedContinuations.isEmpty && text.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.suggestedContinuations, id: \.self) { suggestion in
                            Button {
                                text = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .glassEffect()
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            
            // Input field
            HStack(spacing: 12) {
                TextField("Continue the conversation...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                        .opacity(text.isEmpty ? 0.3 : 1.0)
                }
                .disabled(text.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect()
            .clipShape(Capsule())
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Session Actions Menu
struct SessionActionsMenu: View {
    let session: AmbientSession
    
    var body: some View {
        Menu {
            Button {
                // Export session
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            
            Button {
                // Share insights
            } label: {
                Label("Share Insights", systemImage: "sparkles")
            }
            
            Button {
                // Add to collection
            } label: {
                Label("Add to Collection", systemImage: "folder.badge.plus")
            }
            
            Button {
                // Pin session
            } label: {
                Label("Pin Session", systemImage: "pin")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 40, height: 40)
                .glassEffect()
                .clipShape(Circle())
        }
    }
}

// MARK: - Helper Views
struct StatPill: View {
    let icon: String
    let value: String
    let animated: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect()
        .clipShape(Capsule())
        .scaleEffect(animated ? 1 : 0)
        .opacity(animated ? 1 : 0)
    }
}

struct TopicPill: View {
    let topic: String
    
    var body: some View {
        Text(topic)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect()
            .clipShape(Capsule())
    }
}

// Flow layout for topics
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + viewSize.width > maxWidth, currentX > 0 {
                    currentY += lineHeight + spacing
                    currentX = 0
                    lineHeight = 0
                }
                
                frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: viewSize))
                currentX += viewSize.width + spacing
                lineHeight = max(lineHeight, viewSize.height)
                size.width = max(size.width, currentX - spacing)
            }
            size.height = currentY + lineHeight
        }
    }
}