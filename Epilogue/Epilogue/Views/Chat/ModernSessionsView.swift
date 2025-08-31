import SwiftUI
import SwiftData

struct ModernSessionsView: View {
    @Query(sort: \AmbientSession.startTime, order: .reverse)
    private var sessions: [AmbientSession]
    
    @State private var searchText = ""
    @State private var scrollOffset: CGFloat = 0
    @State private var isHeaderVisible = false
    @Environment(\.modelContext) private var modelContext
    
    private var groupedSessions: [(String, [AmbientSession])] {
        let grouped = Dictionary(grouping: sessions) { session in
            dateGroupKey(for: session.startTime)
        }
        
        return grouped.sorted { first, second in
            dateOrder(first.key) > dateOrder(second.key)
        }
    }
    
    private func dateGroupKey(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "TODAY"
        } else if calendar.isDateInYesterday(date) {
            return "YESTERDAY"
        } else {
            let weekday = calendar.component(.weekday, from: date)
            let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            
            if daysAgo < 7 {
                return calendar.weekdaySymbols[weekday - 1].uppercased()
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d/yy"
                return formatter.string(from: date)
            }
        }
    }
    
    private func dateOrder(_ key: String) -> Int {
        switch key {
        case "TODAY": return 7
        case "YESTERDAY": return 6
        case "SUNDAY": return 5
        case "SATURDAY": return 4
        case "FRIDAY": return 3
        case "THURSDAY": return 2
        case "WEDNESDAY": return 1
        case "TUESDAY": return 0
        case "MONDAY": return -1
        default: return -100
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background - match app background
                Color(red: 0.11, green: 0.11, blue: 0.12)
                    .ignoresSafeArea()
                
                // Main scroll content
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header area with title and search
                            VStack(alignment: .leading, spacing: 24) {
                                // Chat title
                                Text("Chat")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                                    .padding(.top, 60) // Account for status bar
                                
                                // Search bar
                                searchBar
                                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                                    .padding(.bottom, 8)
                            }
                            
                            // Sessions list with sticky headers
                            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                                ForEach(groupedSessions, id: \.0) { group in
                                    Section {
                                        // Session rows
                                        VStack(spacing: 0) {
                                            ForEach(Array(group.1.enumerated()), id: \.1.id) { index, session in
                                                SessionRow(
                                                    session: session,
                                                    showDivider: index < group.1.count - 1
                                                )
                                            }
                                        }
                                        .padding(.bottom, 32)
                                    } header: {
                                        // Sticky section header
                                        SectionHeader(
                                            title: group.0,
                                            count: group.1.count,
                                            scrollOffset: scrollOffset
                                        )
                                    }
                                }
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(
                                        key: ModernScrollOffsetPreferenceKey.self,
                                        value: -geo.frame(in: .named("scroll")).minY
                                    )
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ModernScrollOffsetPreferenceKey.self) { value in
                        // Only update header visibility when crossing threshold to avoid continuous updates
                        let shouldShowHeader = value > 100
                        if isHeaderVisible != shouldShowHeader {
                            isHeaderVisible = shouldShowHeader
                        }
                        // Only update scrollOffset for section headers, throttled
                        if abs(scrollOffset - value) > 5 {
                            scrollOffset = value
                        }
                    }
                }
                
                // Fixed header bar that always shows with proper iOS 26 glass
                VStack(spacing: 0) {
                    // Status bar space
                    Color.clear
                        .frame(height: 50)
                    
                    // Header with proper liquid glass that shows content behind
                    HStack {
                        Text("Chat")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    // NO BACKGROUND! Apply glass directly!
                    .glassEffect(
                        .regular.tint(Color(red: 0.11, green: 0.11, blue: 0.12).opacity(0.5)),
                        in: .rect
                    )
                    .opacity(isHeaderVisible ? 1 : 0)
                }
                .animation(DesignSystem.Animation.easeQuick, value: isHeaderVisible)
            }
            .navigationBarHidden(true)
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.4))
                .font(.system(size: 16))
            
            TextField("Search", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .font(.system(size: 17))
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let count: Int
    let scrollOffset: CGFloat
    
    @State private var isSticky = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))  // Smaller date text
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .tracking(1.5)
            
            Spacer()
            
            // Session count pill - always amber
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 13, weight: .medium))
                Text("sessions")
                    .font(.system(size: 13))
            }
            .foregroundStyle(DesignSystem.Colors.primaryAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.primaryAccent.opacity(0.15))
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        // NO BACKGROUND! Glass effect directly when sticky
        .glassEffect(
            isSticky ? .regular.tint(DesignSystem.Colors.primaryAccent.opacity(0.1)) : .regular,
            in: .rect
        )
        .opacity(isSticky ? 1 : 0.001) // Nearly invisible when not sticky
        .onAppear {
            checkSticky()
        }
        .onChange(of: scrollOffset) { oldValue, newValue in
            // Only check sticky when there's significant scroll change
            if abs(oldValue - newValue) > 10 {
                checkSticky()
            }
        }
    }
    
    private func checkSticky() {
        withAnimation(.easeInOut(duration: 0.15)) {
            // Header becomes sticky after scrolling past search bar
            isSticky = scrollOffset > 150
        }
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: AmbientSession
    let showDivider: Bool
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var sessionSummary: String {
        if let firstQuestion = session.capturedQuestions.first {
            return firstQuestion.content
        } else if let firstQuote = session.capturedQuotes.first {
            return firstQuote.text
        } else if let firstNote = session.capturedNotes.first {
            return firstNote.content
        } else if let book = session.book {
            return "Started exploring \(book.title)"
        } else {
            return "Started exploring a book"
        }
    }
    
    var body: some View {
        NavigationLink(destination: AmbientSessionDetailView(session: session)) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 16) {
                    // Time column
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timeFormatter.string(from: session.startTime))
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(DesignSystem.Colors.textTertiary)
                        
                        // Show "Just started" for very recent sessions
                        if abs(session.startTime.timeIntervalSinceNow) < 300 &&
                           session.capturedQuotes.isEmpty &&
                           session.capturedQuestions.isEmpty &&
                           session.capturedNotes.isEmpty {
                            Text("Just")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                            Text("started")
                                .font(.system(size: 13))
                                .foregroundStyle(DesignSystem.Colors.textQuaternary)
                        }
                    }
                    .frame(width: 70, alignment: .leading)
                    
                    // Content column
                    VStack(alignment: .leading, spacing: 10) {
                        // Book title if available
                        if let book = session.book {
                            Text(book.title.uppercased())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .tracking(1.0)
                        }
                        
                        // Main content text
                        Text(sessionSummary)
                            .font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Item badges
                        HStack(spacing: 16) {
                            if session.capturedQuotes.count > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "quote.bubble.fill")
                                        .font(.system(size: 14))
                                    Text("\(session.capturedQuotes.count)")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.purple)
                            }
                            
                            if session.capturedQuestions.count > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "questionmark.circle.fill")
                                        .font(.system(size: 14))
                                    Text("\(session.capturedQuestions.count)")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.blue)
                            }
                            
                            if session.capturedNotes.count > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 14))
                                    Text("\(session.capturedNotes.count)")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.green)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // No chevron - removed per request
                }
                .padding(.horizontal, DesignSystem.Spacing.listItemPadding)
                .padding(.vertical, 20)
                
                // Divider if needed
                if showDivider {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 0.5)
                        .padding(.leading, 20)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Scroll Offset Preference Key
struct ModernScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Session Detail View
struct AmbientSessionDetailView: View {
    let session: AmbientSession
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Session info header
                if let book = session.book {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            // Session time
                            Text(session.startTime, style: .date)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        
                        Spacer()
                        
                        if let coverURL = book.coverImageURL {
                            SharedBookCoverView(
                                coverURL: coverURL,
                                width: 60,
                                height: 90
                            )
                            .cornerRadius(8)
                            .shadow(radius: 10)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // Questions section
                if !session.capturedQuestions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Questions")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal)
                        
                        ForEach(session.capturedQuestions) { question in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(question.content)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                
                                if let answer = question.answer {
                                    Text(answer)
                                        .font(.callout)
                                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Quotes section
                if !session.capturedQuotes.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quotes")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal)
                        
                        ForEach(session.capturedQuotes) { quote in
                            Text(quote.text)
                                .font(.custom("Georgia", size: 17))
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                }
                
                // Notes section
                if !session.capturedNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notes")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal)
                        
                        ForEach(session.capturedNotes) { note in
                            Text(note.content)
                                .font(.body)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .navigationTitle("Session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundStyle(DesignSystem.Colors.primaryAccent)
            }
        }
    }
}

#Preview {
    ModernSessionsView()
        .preferredColorScheme(.dark)
}