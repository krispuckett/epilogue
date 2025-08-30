import SwiftUI
import SwiftData

struct PerplexityStyleSessionsView: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse)
    private var sessions: [AmbientSession]
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedSession: AmbientSession?
    @State private var scrollOffset: CGFloat = 0
    @State private var stickyHeaders: Set<String> = []
    @Environment(\.modelContext) private var modelContext
    
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                
                TextField("Search sessions...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        DesignSystem.HapticFeedback.light()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // Group sessions by date
    private var groupedSessions: [(date: String, sessions: [AmbientSession])] {
        let calendar = Calendar.current
        let now = Date()
        
        let grouped = Dictionary(grouping: sessions) { session in
            let startOfToday = calendar.startOfDay(for: now)
            let startOfSession = calendar.startOfDay(for: session.startTime)
            let daysAgo = calendar.dateComponents([.day], from: startOfSession, to: startOfToday).day ?? 0
            
            if daysAgo == 0 {
                return "TODAY"
            } else if daysAgo == 1 {
                return "YESTERDAY"
            } else {
                // Use numeric date for everything older than yesterday
                let formatter = DateFormatter()
                formatter.dateFormat = "M.dd.yy"
                return formatter.string(from: session.startTime)
            }
        }
        
        // Sort groups by date (most recent first)
        let sortedGroups = grouped.sorted { group1, group2 in
            guard let date1 = group1.value.first?.startTime,
                  let date2 = group2.value.first?.startTime else {
                return false
            }
            return date1 > date2
        }
        
        return sortedGroups.map { (date: $0.key, sessions: $0.value.sorted { $0.startTime > $1.startTime }) }
    }
    
    private var filteredGroupedSessions: [(date: String, sessions: [AmbientSession])] {
        if searchText.isEmpty {
            return groupedSessions
        }
        
        return groupedSessions.compactMap { group in
            let filteredSessions = group.sessions.filter { session in
                // Search in book title
                if let bookTitle = session.bookModel?.title,
                   bookTitle.localizedCaseInsensitiveContains(searchText) {
                    return true
                }
                
                // Search in questions
                if session.capturedQuestions.contains(where: { $0.content.localizedCaseInsensitiveContains(searchText) }) {
                    return true
                }
                
                // Search in notes
                if session.capturedNotes.contains(where: { $0.content.localizedCaseInsensitiveContains(searchText) }) {
                    return true
                }
                
                // Search in quotes
                if session.capturedQuotes.contains(where: { $0.text.localizedCaseInsensitiveContains(searchText) }) {
                    return true
                }
                
                return false
            }
            
            return filteredSessions.isEmpty ? nil : (date: group.date, sessions: filteredSessions)
        }
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Chat")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        searchButton
                    }
                }
                .sheet(item: $selectedSession) { session in
                    NavigationStack {
                        AmbientSessionSummaryView(
                            session: session,
                            colorPalette: nil
                        )
                    }
                }
        }
    }
    
    @ViewBuilder
    private var searchButton: some View {
        Button {
            withAnimation(DesignSystem.Animation.springStandard) {
                isSearching.toggle()
                if !isSearching {
                    searchText = ""
                }
            }
            DesignSystem.HapticFeedback.light()
        } label: {
            if isSearching {
                // Liquid glass close button with amber tint
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .glassEffect()
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignSystem.Colors.primaryAccent)
                }
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Dark background matching library and notes
            DesignSystem.Colors.surfaceBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Progressive Search Bar (like NotesView)
                    if isSearching {
                        searchBar
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ChatScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minY)
                }
                .frame(height: 0)
                
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(Array(filteredGroupedSessions.enumerated()), id: \.0) { index, group in
                        Section {
                            ForEach(group.sessions) { session in
                                PerplexitySessionRow(
                                    session: session,
                                    onTap: {
                                        selectedSession = session
                                    }
                                )
                            }
                        } header: {
                            StickyDateHeader(
                                dateLabel: group.date,
                                sessionCount: group.sessions.count,
                                isSticky: scrollOffset < -5,  // More sensitive threshold
                                scrollOffset: scrollOffset
                            )
                            .id(group.date)
                        }
                    }
                }
                .padding(.bottom, 100)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ChatScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
    }
}

// MARK: - Chat Scroll Offset Preference Key
struct ChatScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Sticky Date Header  
struct StickyDateHeader: View {
    let dateLabel: String
    let sessionCount: Int
    let isSticky: Bool  
    let scrollOffset: CGFloat
    @State private var isPinned = false
    
    var body: some View {
        HStack {
            Text(dateLabel)
                .font(.system(
                    size: isPinned ? 15 : 13,
                    weight: isPinned ? .bold : .semibold
                ))
                .foregroundStyle(
                    isPinned ? .white : DesignSystem.Colors.textTertiary
                )
                .tracking(isPinned ? 1.4 : 1.2)
            
            Spacer()
            
            Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                .font(.system(
                    size: isPinned ? 12 : 11,
                    weight: .medium
                ))
                .foregroundStyle(
                    isPinned ? DesignSystem.Colors.primaryAccent : DesignSystem.Colors.textQuaternary
                )
        }
        .padding(.horizontal, DesignSystem.Spacing.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                // Header is pinned when it's at the top of the screen
                let pinned = minY <= 150  // Adjust threshold as needed
                
                Color.clear
                    .onAppear {
                        isPinned = pinned
                    }
                    .onChange(of: minY) { _, newValue in
                        withAnimation(.smooth(duration: 0.2)) {
                            isPinned = newValue <= 150
                        }
                    }
            }
            .frame(height: 0)
            
            if isPinned {
                // Amber tinted rectangular card with proper glass effect
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.10))
                    .glassEffect(.regular, in: .rect(cornerRadius: DesignSystem.CornerRadius.medium))
                    .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            } else {
                // Base background
                DesignSystem.Colors.surfaceBackground
            }
        }
    }
}

// MARK: - Perplexity Session Row
struct PerplexitySessionRow: View {
    let session: AmbientSession
    let onTap: () -> Void
    
    private var timeDisplay: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's from today
        if calendar.isDateInToday(session.startTime) {
            // Check if it's very recent (within last hour)
            let minutesAgo = Int(now.timeIntervalSince(session.startTime) / 60)
            if minutesAgo < 60 {
                return "Just started"
            } else {
                formatter.dateFormat = "h:mm a"
                return formatter.string(from: session.startTime)
            }
        } else if calendar.isDateInYesterday(session.startTime) {
            return "Yesterday"
        } else {
            // For older dates, show the numeric date
            formatter.dateFormat = "M.dd.yy"
            return formatter.string(from: session.startTime)
        }
    }
    
    private var primaryTimeDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: session.startTime).uppercased()
    }
    
    private var secondaryTimeDisplay: String? {
        let calendar = Calendar.current
        let now = Date()
        let minutesAgo = Int(now.timeIntervalSince(session.startTime) / 60)
        
        if calendar.isDateInToday(session.startTime) && minutesAgo < 60 {
            return "Just\nstarted"
        }
        return nil
    }
    
    private var sessionTitle: String {
        // If it's a general session without a book
        guard let bookModel = session.bookModel else {
            return "Started exploring a book"
        }
        
        // Check for specific content to make title more contextual
        if let firstQuestion = session.capturedQuestions.first {
            return firstQuestion.content
        }
        
        if let firstNote = session.capturedNotes.first {
            let preview = String(firstNote.content.prefix(100))
            return preview
        }
        
        if session.capturedQuotes.count > 0 {
            return "Started exploring \(bookModel.title)"
        }
        
        return "Started exploring \(bookModel.title)"
    }
    
    private var bookTitleDisplay: String? {
        session.bookModel?.title.uppercased()
    }
    
    private var hasContent: Bool {
        !session.capturedQuestions.isEmpty || 
        !session.capturedNotes.isEmpty || 
        !session.capturedQuotes.isEmpty
    }
    
    private var contentIcon: (name: String, color: Color)? {
        if !session.capturedQuestions.isEmpty {
            return ("questionmark.circle.fill", Color(red: 0.4, green: 0.6, blue: 1.0))
        } else if !session.capturedNotes.isEmpty {
            return ("square.and.pencil", Color(red: 0.8, green: 0.4, blue: 1.0))
        } else if !session.capturedQuotes.isEmpty {
            return ("quote.bubble.fill", DesignSystem.Colors.primaryAccent)
        }
        return nil
    }
    
    private var contentCount: Int {
        session.capturedQuestions.count + 
        session.capturedNotes.count + 
        session.capturedQuotes.count
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                // Time column with smaller font
                VStack(alignment: .leading, spacing: 2) {
                    Text(primaryTimeDisplay)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    if let secondary = secondaryTimeDisplay {
                        Text(secondary)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.25))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(width: 70, alignment: .leading)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Book title if available
                    if let bookTitle = bookTitleDisplay {
                        HStack(spacing: 8) {
                            Text(bookTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(1.0)
                            
                            if let icon = contentIcon {
                                Image(systemName: icon.name)
                                    .font(.system(size: 12))
                                    .foregroundStyle(icon.color)
                            }
                        }
                    }
                    
                    // Session content
                    Text(sessionTitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Content count badge if there's content
                    if hasContent && contentCount > 1 {
                        HStack(spacing: 8) {
                            if let icon = contentIcon {
                                Image(systemName: icon.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(icon.color)
                            }
                            Text("\(contentCount)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(DesignSystem.Colors.textTertiary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    PerplexityStyleSessionsView()
        .preferredColorScheme(.dark)
}