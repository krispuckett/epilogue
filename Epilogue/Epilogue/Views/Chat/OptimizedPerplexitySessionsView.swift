import SwiftUI
import SwiftData

// MARK: - Optimized Perplexity Sessions View
struct OptimizedPerplexitySessionsView: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse)
    private var sessions: [AmbientSession]
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedSession: AmbientSession?
    @Environment(\.modelContext) private var modelContext
    
    // Pre-computed data to avoid recalculation during scroll
    @State private var cachedGroupedSessions: [(date: String, sessions: [AmbientSession])] = []
    @State private var isInitialLoad = true
    
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
                .task {
                    // Pre-compute grouped sessions once
                    if isInitialLoad {
                        await computeGroupedSessions()
                        isInitialLoad = false
                    }
                }
                .onChange(of: sessions) { _, _ in
                    Task {
                        await computeGroupedSessions()
                    }
                }
        }
    }
    
    @ViewBuilder
    private var searchButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSearching.toggle()
                if !isSearching {
                    searchText = ""
                }
            }
            HapticManager.shared.lightTap()
        } label: {
            if isSearching {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.15))
                        .frame(width: 28, height: 28)
                        .glassEffect()
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                }
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                
                TextField("Search sessions...", text: $searchText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        HapticManager.shared.lightTap()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color(red: 0.11, green: 0.105, blue: 0.102)
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    if isSearching {
                        searchBar
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    
                    // Keep LazyVStack for sticky headers but optimize content
                    ForEach(Array(filteredSessions.enumerated()), id: \.0) { index, group in
                        Section {
                            ForEach(group.sessions) { session in
                                OptimizedSessionRow(
                                    session: session,
                                    onTap: {
                                        selectedSession = session
                                    }
                                )
                            }
                        } header: {
                            OptimizedStickyHeader(
                                dateLabel: group.date,
                                sessionCount: group.sessions.count
                            )
                            .id(group.date)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    // Computed only when search text changes
    private var filteredSessions: [(date: String, sessions: [AmbientSession])] {
        if searchText.isEmpty {
            return cachedGroupedSessions
        }
        
        return cachedGroupedSessions.compactMap { group in
            let filtered = group.sessions.filter { session in
                // Simplified search logic
                let searchLower = searchText.lowercased()
                
                if let bookTitle = session.bookModel?.title.lowercased(),
                   bookTitle.contains(searchLower) {
                    return true
                }
                
                // Quick check in first items only to avoid iterating all
                if let firstQuestion = session.capturedQuestions.first,
                   firstQuestion.content.lowercased().contains(searchLower) {
                    return true
                }
                
                if let firstNote = session.capturedNotes.first,
                   firstNote.content.lowercased().contains(searchLower) {
                    return true
                }
                
                return false
            }
            
            return filtered.isEmpty ? nil : (date: group.date, sessions: filtered)
        }
    }
    
    // Pre-compute grouping to avoid recalculation during scroll
    @MainActor
    private func computeGroupedSessions() async {
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
                let formatter = DateFormatter()
                formatter.dateFormat = "M.dd.yy"
                return formatter.string(from: session.startTime)
            }
        }
        
        cachedGroupedSessions = grouped
            .sorted { $0.value.first?.startTime ?? Date() > $1.value.first?.startTime ?? Date() }
            .map { (date: $0.key, sessions: $0.value.sorted { $0.startTime > $1.startTime }) }
    }
}

// MARK: - Optimized Sticky Header with Amber Glass
struct OptimizedStickyHeader: View {
    let dateLabel: String
    let sessionCount: Int
    @State private var isPinned = false
    
    var body: some View {
        HStack {
            Text(dateLabel)
                .font(.system(
                    size: isPinned ? 15 : 13,
                    weight: isPinned ? .bold : .semibold
                ))
                .foregroundStyle(
                    isPinned ? .white : .white.opacity(0.5)
                )
                .tracking(isPinned ? 1.4 : 1.2)
                .animation(.easeInOut(duration: 0.2), value: isPinned)
            
            Spacer()
            
            Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                .font(.system(
                    size: isPinned ? 12 : 11,
                    weight: .medium
                ))
                .foregroundStyle(
                    isPinned ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white.opacity(0.3)
                )
                .animation(.easeInOut(duration: 0.2), value: isPinned)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background {
            // Optimized background with single GeometryReader
            GeometryReader { geo in
                let minY = geo.frame(in: .global).minY
                
                Color.clear
                    .onChange(of: minY) { _, newValue in
                        // Only update if state actually changes to reduce updates
                        let shouldPin = newValue <= 150
                        if shouldPin != isPinned {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPinned = shouldPin
                            }
                        }
                    }
                    .onAppear {
                        isPinned = geo.frame(in: .global).minY <= 150
                    }
            }
            .frame(height: 0)
            
            if isPinned {
                // Beautiful amber tinted glass effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.08))
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .animation(.easeInOut(duration: 0.3), value: isPinned)
            } else {
                Color(red: 0.11, green: 0.105, blue: 0.102)
            }
        }
    }
}

// MARK: - Optimized Session Row (Pre-computed values)
struct OptimizedSessionRow: View {
    let session: AmbientSession
    let onTap: () -> Void
    
    // Pre-compute expensive values
    private var displayData: SessionDisplayData {
        SessionDisplayData(session: session)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 16) {
                // Time column
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayData.timeDisplay)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    if displayData.isJustStarted {
                        Text("Just\nstarted")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.25))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(width: 70, alignment: .leading)
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    if let bookTitle = displayData.bookTitle {
                        HStack(spacing: 8) {
                            Text(bookTitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(1.0)
                            
                            if displayData.hasQuestions {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 0.4, green: 0.6, blue: 1.0))
                            }
                        }
                    }
                    
                    Text(displayData.title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if displayData.contentCount > 1 {
                        HStack(spacing: 8) {
                            Image(systemName: displayData.contentIcon)
                                .font(.system(size: 11))
                                .foregroundStyle(displayData.contentColor)
                            
                            Text("\(displayData.contentCount)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Pre-computed Display Data
struct SessionDisplayData {
    let timeDisplay: String
    let isJustStarted: Bool
    let bookTitle: String?
    let title: String
    let hasQuestions: Bool
    let contentCount: Int
    let contentIcon: String
    let contentColor: Color
    
    init(session: AmbientSession) {
        // Pre-compute time display
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        self.timeDisplay = formatter.string(from: session.startTime).uppercased()
        
        // Check if just started
        let minutesAgo = Int(Date().timeIntervalSince(session.startTime) / 60)
        self.isJustStarted = Calendar.current.isDateInToday(session.startTime) && minutesAgo < 60
        
        // Book title
        self.bookTitle = session.bookModel?.title.uppercased()
        
        // Session title
        if let firstQuestion = session.capturedQuestions.first {
            self.title = firstQuestion.content
        } else if let firstNote = session.capturedNotes.first {
            self.title = String(firstNote.content.prefix(100))
        } else if let bookModel = session.bookModel {
            self.title = "Started exploring \(bookModel.title)"
        } else {
            self.title = "Started exploring a book"
        }
        
        // Content metrics
        self.hasQuestions = !session.capturedQuestions.isEmpty
        self.contentCount = session.capturedQuestions.count + 
                           session.capturedNotes.count + 
                           session.capturedQuotes.count
        
        // Content icon and color
        if !session.capturedQuestions.isEmpty {
            self.contentIcon = "questionmark.circle.fill"
            self.contentColor = Color(red: 0.4, green: 0.6, blue: 1.0)
        } else if !session.capturedNotes.isEmpty {
            self.contentIcon = "square.and.pencil"
            self.contentColor = Color(red: 0.8, green: 0.4, blue: 1.0)
        } else {
            self.contentIcon = "quote.bubble.fill"
            self.contentColor = Color(red: 1.0, green: 0.55, blue: 0.26)
        }
    }
}