import SwiftUI
import SwiftData

// MARK: - Native iOS-Style Notes List
struct NativeNotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var notesViewModel: NotesViewModel
    @StateObject private var intelligenceEngine = NoteIntelligenceEngine.shared
    
    // Queries
    @Query(sort: \CapturedNote.timestamp, order: .reverse) private var notes: [CapturedNote]
    @Query(sort: \CapturedQuote.timestamp, order: .reverse) private var quotes: [CapturedQuote]
    @Query(sort: \CapturedQuestion.timestamp, order: .reverse) private var questions: [CapturedQuestion]
    
    // View State
    @State private var searchText = ""
    @State private var isSearchFocused = false
    @State private var editingNote: Note?
    @State private var showingSectionsNavigator = false
    
    // Computed properties
    private var allNotes: [Note] {
        var items: [Note] = []
        items += notes.map { $0.toNote() }
        items += quotes.map { $0.toNote() }
        items += questions.map { $0.toNote() }
        return items.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    // Smart time-based grouping
    private var groupedNotes: [(String, [Note])] {
        let now = Date()
        let calendar = Calendar.current
        
        var groups: [String: [Note]] = [:]
        
        for note in allNotes {
            let timeInterval = now.timeIntervalSince(note.dateCreated)
            
            let groupKey: String
            if timeInterval < 3600 { // Less than 1 hour
                groupKey = "Just Now"
            } else if calendar.isDateInToday(note.dateCreated) {
                groupKey = "Today"
            } else if calendar.isDateInYesterday(note.dateCreated) {
                groupKey = "Yesterday"
            } else if timeInterval < 604800 { // Less than a week
                groupKey = "This Week"
            } else if timeInterval < 2592000 { // Less than 30 days
                groupKey = "This Month"
            } else {
                // Group by month
                let formatter = DateFormatter()
                formatter.dateFormat = "MMMM yyyy"
                groupKey = formatter.string(from: note.dateCreated)
            }
            
            groups[groupKey, default: []].append(note)
        }
        
        // Sort groups by recency
        let sortedGroups = groups.sorted { group1, group2 in
            guard let date1 = group1.value.first?.dateCreated,
                  let date2 = group2.value.first?.dateCreated else { return false }
            return date1 > date2
        }
        
        return sortedGroups
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Clean black background
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Search bar when focused
                        if isSearchFocused || !searchText.isEmpty {
                            searchBar
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        // Content
                        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                            if groupedNotes.isEmpty {
                                emptyState
                                    .padding(.top, 100)
                            } else {
                                ForEach(groupedNotes, id: \.0) { groupName, groupNotes in
                                    Section {
                                        ForEach(groupNotes) { note in
                                            NoteRow(
                                                note: note,
                                                isFirstInGroup: groupNotes.first?.id == note.id,
                                                onTap: {
                                                    editingNote = note
                                                    HapticManager.shared.lightTap()
                                                },
                                                onDelete: {
                                                    deleteNote(note)
                                                }
                                            )
                                        }
                                    } header: {
                                        SectionHeader(title: groupName, count: groupNotes.count)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 100)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable {
                    await refreshContent()
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showingSectionsNavigator.toggle()
                        }
                        HapticManager.shared.lightTap()
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isSearchFocused.toggle()
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                    }
                }
            }
            .sheet(item: $editingNote) { note in
                InlineEditSheet(note: note)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .ambientSectionsNavigator(
                isShowing: $showingSectionsNavigator,
                sections: intelligenceEngine.smartSections,
                onSectionTap: { _ in }
            )
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.white.opacity(0.5))
                .font(.system(size: 16))
            
            TextField("Search notes...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.white)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Notes Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            
            Text("Your thoughts and quotes will appear here")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
    
    private func refreshContent() async {
        let quotesAsNotes = quotes.map { $0.toNote() }
        await intelligenceEngine.processNotes(allNotes, quotes: quotesAsNotes, questions: questions)
    }
    
    private func deleteNote(_ note: Note) {
        if note.type == .quote {
            if let quote = quotes.first(where: { $0.id == note.id }) {
                modelContext.delete(quote)
            }
        } else {
            if let capturedNote = notes.first(where: { $0.id == note.id }) {
                modelContext.delete(capturedNote)
            }
        }
        
        do {
            try modelContext.save()
            HapticManager.shared.success()
        } catch {
            print("Failed to delete note: \(error)")
            HapticManager.shared.error()
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            
            Spacer()
            
            if count > 3 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black)
    }
}

// MARK: - Note Row
struct NoteRow: View {
    let note: Note
    let isFirstInGroup: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Type indicator
                Image(systemName: note.type == .quote ? "quote.bubble.fill" : "note.text")
                    .font(.system(size: 16))
                    .foregroundStyle(note.type == .quote ? Color.yellow.opacity(0.7) : Color.blue.opacity(0.7))
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Content
                    Text(note.content)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Metadata
                    HStack(spacing: 4) {
                        if let bookTitle = note.bookTitle {
                            Text(bookTitle)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                        }
                        
                        if note.bookTitle != nil {
                            Text("·")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.3))
                        }
                        
                        Text(RelativeDateFormatter.shared.string(from: note.dateCreated))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(isPressed ? Color.white.opacity(0.05) : Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Relative Date Formatter
class RelativeDateFormatter {
    static let shared = RelativeDateFormatter()
    
    private let formatter = DateFormatter()
    private let relativeFormatter = RelativeDateTimeFormatter()
    
    init() {
        relativeFormatter.unitsStyle = .abbreviated
    }
    
    func string(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 { // Less than 1 minute
            return "now"
        } else if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m"
        } else if timeInterval < 86400 { // Less than 1 day
            let hours = Int(timeInterval / 3600)
            return "\(hours)h"
        } else if timeInterval < 604800 { // Less than 1 week
            let days = Int(timeInterval / 86400)
            return "\(days)d"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}