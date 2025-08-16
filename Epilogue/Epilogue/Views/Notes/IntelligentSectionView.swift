import SwiftUI

// MARK: - Intelligent Section View
struct IntelligentSectionView: View {
    let section: SmartSection
    @Binding var isExpanded: Bool
    let onNoteTap: (Note) -> Void
    let onLongPress: (Note, CGRect) -> Void
    let onDoubleTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onSwipe: (Note, SwipeDirection) -> Void
    
    @State private var breathingScale: CGFloat = 1.0
    @State private var cardOffsets: [UUID: CGFloat] = [:]
    @State private var showingInsights = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var animation
    
    // Layout constants
    private let collapsedHeight: CGFloat = 180
    private let cardSpacing: CGFloat = 16
    private let peekIndicatorHeight: CGFloat = 3
    private let peekIndicatorSpacing: CGFloat = 6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Intelligent Header with AI Summary
            intelligentHeader
            
            // Content Area
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.3)),
                        removal: .opacity.animation(.easeIn(duration: 0.2))
                    ))
            } else {
                collapsedContent
                    .transition(.identity)
            }
        }
        .scaleEffect(breathingScale)
        .animation(
            reduceMotion ? .linear(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.8),
            value: isExpanded
        )
        .onAppear {
            if !isExpanded {
                startBreathing()
            }
        }
        .onChange(of: isExpanded) { expanded in
            if expanded {
                stopBreathing()
            } else {
                startBreathing()
            }
        }
    }
    
    // MARK: - Intelligent Header
    private var intelligentHeader: some View {
        Button(action: toggleExpansion) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Section Icon
                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(section.color)
                        .frame(width: 20, height: 20)
                    
                    // Section Title
                    Text(section.title)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundStyle(.white)
                    
                    // Count Badge
                    Text("\(section.notes.count)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .glassEffect(
                            .regular.tint(section.color.opacity(0.1)),
                            in: Capsule()
                        )
                    
                    Spacer()
                    
                    // Expansion Indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                
                // AI-generated insight (subtle)
                if !isExpanded && section.notes.count > 3 {
                    Text(generateInsight())
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .buttonStyle(PlainButtonStyle())
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isExpanded)
    }
    
    // MARK: - Collapsed Content (Clean Stack)
    private var collapsedContent: some View {
        VStack(spacing: 0) {
            // Main visible card
            if let firstNote = section.notes.first {
                NoteCardView(note: firstNote)
                    .padding(.horizontal, 16)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded = true
                        }
                    }
                    .onLongPressGesture {
                        HapticManager.shared.mediumTap()
                        onLongPress(firstNote, CGRect(origin: .zero, size: .zero))
                    }
            }
            
            // Subtle depth indicators (not overlapping cards!)
            if section.notes.count > 1 {
                HStack(spacing: peekIndicatorSpacing) {
                    ForEach(0..<min(3, section.notes.count - 1), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(section.color.opacity(0.3 - Double(index) * 0.1))
                            .frame(height: peekIndicatorHeight)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
    }
    
    // MARK: - Expanded Content (Beautiful List)
    private var expandedContent: some View {
        LazyVStack(spacing: cardSpacing) {
            ForEach(section.notes) { note in
                noteCardWithGestures(note: note)
            }
            
            // AI Insights Footer (when expanded)
            if isExpanded && section.notes.count > 5 {
                insightsFooter
            }
        }
        .padding(.bottom, 16)
    }
    
    // Helper view for note card with gestures
    private func noteCardWithGestures(note: Note) -> some View {
        NoteCardView(note: note)
            .padding(.horizontal, 16)
            .transition(
                .asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                )
            )
            .onTapGesture {
                onNoteTap(note)
            }
            .onLongPressGesture {
                HapticManager.shared.mediumTap()
                onLongPress(note, CGRect(origin: .zero, size: .zero))
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        cardOffsets[note.id] = value.translation.width
                    }
                    .onEnded { value in
                        if abs(value.translation.width) > 100 {
                            onSwipe(note, value.translation.width > 0 ? .right : .left)
                        }
                        withAnimation(.spring()) {
                            cardOffsets[note.id] = 0
                        }
                    }
            )
            .offset(x: cardOffsets[note.id] ?? 0)
    }
    
    // MARK: - Note Card View (Preserving your design!)
    private func NoteCardView(note: Note) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                if let bookTitle = note.bookTitle {
                    Text(bookTitle.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                        .tracking(0.5)
                }
                
                Spacer()
                
                Text(note.formattedDate)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            // Content (using your monospaced font for notes!)
            Text(note.content)
                .font(.system(size: 15, design: note.type == .note ? .monospaced : .serif))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(isExpanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: !isExpanded)
            
            // Author for quotes (keeping your design!)
            if note.type == .quote, let author = note.author {
                HStack {
                    Text("— \(author)")
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular.tint(Color.white.opacity(0.05)),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
    
    // MARK: - Insights Footer
    private var insightsFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundStyle(section.color)
                
                Text("Pattern Detected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                
                Spacer()
            }
            
            Text(generateDeepInsight())
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(2)
        }
        .padding(12)
        .padding(.horizontal, 16)
        .glassEffect(
            .regular.tint(section.color.opacity(0.05)),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Helper Functions
    private func toggleExpansion() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isExpanded.toggle()
            HapticManager.shared.lightTap()
        }
    }
    
    private func startBreathing() {
        guard !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 3)
                .repeatForever(autoreverses: true)
        ) {
            breathingScale = 1.008
        }
    }
    
    private func stopBreathing() {
        withAnimation(.easeOut(duration: 0.3)) {
            breathingScale = 1.0
        }
    }
    
    private func generateInsight() -> String {
        // Simple insight generation based on section type and content
        switch section.type {
        case .questionsToExplore:
            return "Exploring \(section.notes.count) curious threads..."
        case .goldenQuotes:
            return "Wisdom from \(Set(section.notes.compactMap { $0.author }).count) voices"
        case .todaysThoughts:
            return "Fresh perspectives from today's reading"
        case .continueReading:
            return "Pick up where you left off"
        case .connections:
            return "Ideas connecting across \(Set(section.notes.compactMap { $0.bookTitle }).count) books"
        default:
            return "Curated by your reading patterns"
        }
    }
    
    private func generateDeepInsight() -> String {
        // Deeper insight for expanded view
        let bookCount = Set(section.notes.compactMap { $0.bookTitle }).count
        let avgLength = section.notes.map { $0.content.count }.reduce(0, +) / max(section.notes.count, 1)
        
        if avgLength > 200 {
            return "You're capturing detailed thoughts - these notes average \(avgLength) characters"
        } else if bookCount > 2 {
            return "These ideas span \(bookCount) different books, showing interconnected thinking"
        } else {
            return "This collection reveals a focused exploration of key themes"
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 24) {
                IntelligentSectionView(
                    section: SmartSection(
                        id: UUID(),
                        type: .questionsToExplore,
                        title: "Questions to Explore",
                        icon: "questionmark.circle",
                        notes: [
                            Note(type: .note, content: "Who is the leader of the El?", bookId: nil, bookTitle: "The Lord of the Rings", author: "J.R.R. Tolkien", pageNumber: nil, dateCreated: Date(), id: UUID()),
                            Note(type: .note, content: "What is the significance of the ring's inscription?", bookId: nil, bookTitle: "The Lord of the Rings", author: "J.R.R. Tolkien", pageNumber: nil, dateCreated: Date().addingTimeInterval(-3600), id: UUID()),
                            Note(type: .note, content: "How does power corrupt in Middle-earth?", bookId: nil, bookTitle: "The Lord of the Rings", author: "J.R.R. Tolkien", pageNumber: nil, dateCreated: Date().addingTimeInterval(-7200), id: UUID())
                        ],
                        color: Color(red: 1.0, green: 0.55, blue: 0.26)
                    ),
                    isExpanded: .constant(false),
                    onNoteTap: { _ in },
                    onLongPress: { _, _ in },
                    onDoubleTap: { _ in },
                    onDelete: { _ in },
                    onSwipe: { _, _ in }
                )
                
                IntelligentSectionView(
                    section: SmartSection(
                        id: UUID(),
                        type: .goldenQuotes,
                        title: "Golden Quotes",
                        icon: "quote.bubble",
                        notes: [
                            Note(type: .quote, content: "All we have to decide is what to do with the time that is given us.", bookId: nil, bookTitle: "The Fellowship of the Ring", author: "Gandalf", pageNumber: nil, dateCreated: Date(), id: UUID())
                        ],
                        color: Color.blue
                    ),
                    isExpanded: .constant(true),
                    onNoteTap: { _ in },
                    onLongPress: { _, _ in },
                    onDoubleTap: { _ in },
                    onDelete: { _ in },
                    onSwipe: { _, _ in }
                )
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}