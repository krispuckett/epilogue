import SwiftUI

struct NotesView: View {
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    @State private var selectedFilter: NoteType? = nil
    @State private var showingAddNote = false
    @State private var noteToEdit: Note? = nil
    @State private var editingNote: Note? = nil
    @State private var openOptionsNoteId: UUID? = nil
    @State private var highlightedNoteId: UUID? = nil
    @State private var scrollToNoteId: UUID? = nil
    @State private var contextMenuNote: Note? = nil
    @State private var contextMenuSourceRect: CGRect = .zero
    
    @Namespace private var commandPaletteNamespace
    @Namespace private var noteTransition
    
    // Filtered notes based on filter
    var filteredNotes: [Note] {
        var filtered = notesViewModel.notes
        
        if let selectedFilter = selectedFilter {
            filtered = filtered.filter { $0.type == selectedFilter }
        }
        
        return filtered.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    // Helper function to create note card view
    @ViewBuilder
    private func noteCardView(for note: Note) -> some View {
        NoteCard(
            note: note,
            isSelectionMode: false,
            isSelected: false,
            onSelectionToggle: { },
            openOptionsNoteId: $openOptionsNoteId,
            onContextMenuRequest: { note, rect in
                contextMenuNote = note
                contextMenuSourceRect = rect
            }
        )
        .environmentObject(notesViewModel)
        .matchedTransitionSource(id: note.id, in: noteTransition)
        .id(note.id)
        .overlay(highlightOverlay(for: note))
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
        .onTapGesture(count: 2) {
            // Direct test - bypass the callback chain
            HapticManager.shared.mediumTap()
            contextMenuNote = note
            contextMenuSourceRect = CGRect(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2, width: 100, height: 100)
        }
    }
    
    // Helper function for highlight overlay
    @ViewBuilder
    private func highlightOverlay(for note: Note) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 3)
            .opacity(highlightedNoteId == note.id ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: highlightedNoteId)
    }
    
    var body: some View {
        ZStack {
            // Match the app's dark background
            Color.black
                .ignoresSafeArea()
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                    // Filter pills at the top of content
                    HStack(spacing: 8) {
                        FilterPill(
                            title: "All",
                            count: notesViewModel.notes.count,
                            isActive: selectedFilter == nil,
                            action: { selectedFilter = nil }
                        )
                        
                        FilterPill(
                            title: "Quote",
                            count: notesViewModel.notes.filter { $0.type == .quote }.count,
                            icon: "quote.opening",
                            isActive: selectedFilter == .quote,
                            action: { selectedFilter = selectedFilter == .quote ? nil : .quote }
                        )
                        
                        FilterPill(
                            title: "Note",
                            count: notesViewModel.notes.filter { $0.type == .note }.count,
                            icon: "note.text",
                            isActive: selectedFilter == .note,
                            action: { selectedFilter = selectedFilter == .note ? nil : .note }
                        )
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Notes grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(filteredNotes) { note in
                            noteCardView(for: note)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 80)
            }
            .onChange(of: scrollToNoteId) { _, noteId in
                if let noteId = noteId {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(noteId, anchor: .center)
                    }
                    // Clear the scroll request after scrolling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollToNoteId = nil
                    }
                }
            }
        } // End ScrollViewReader
        
        // Context menu overlay
        if let contextMenuNote = contextMenuNote {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    self.contextMenuNote = nil
                }
            
            NoteContextMenu(
                note: contextMenuNote,
                sourceRect: contextMenuSourceRect,
                isPresented: Binding(
                    get: { self.contextMenuNote != nil },
                    set: { if !$0 { self.contextMenuNote = nil } }
                )
            )
            .environmentObject(notesViewModel)
            .zIndex(1000)
        }
        }
        .navigationTitle("Notes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddNote = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            LiquidCommandPalette(
                isPresented: $showingAddNote,
                animationNamespace: commandPaletteNamespace
            )
            .environmentObject(notesViewModel)
            .environmentObject(libraryViewModel)
        }
        .sheet(item: $noteToEdit) { note in
            LiquidCommandPalette(
                isPresented: .constant(true),
                animationNamespace: commandPaletteNamespace,
                initialContent: formatNoteForEditing(note),
                editingNote: note,
                onUpdate: { updatedNote in
                    notesViewModel.updateNote(updatedNote)
                    noteToEdit = nil
                }
            )
            .environmentObject(notesViewModel)
            .environmentObject(libraryViewModel)
            .onDisappear {
                noteToEdit = nil
                notesViewModel.isEditingNote = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EditNote"))) { notification in
            if let note = notification.object as? Note {
                editingNote = note
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NavigateToNote"))) { notification in
            if let note = notification.object as? Note {
                // Scroll to and highlight the note
                scrollToNoteId = note.id
                highlightedNoteId = note.id
                
                // Remove highlight after a delay, then open for editing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        highlightedNoteId = nil
                    }
                    // Open the note for editing
                    editingNote = note
                }
            }
        }
        .sheet(item: $editingNote) { note in
            NoteEditSheet(note: note)
                .environmentObject(notesViewModel)
        }
        .sensoryFeedback(.impact, trigger: editingNote)
    }
    
    private func formatNoteForEditing(_ note: Note) -> String {
        switch note.type {
        case .note:
            return "note: \(note.content)"
        case .quote:
            var cleanContent = note.content.trimmingCharacters(in: .whitespaces)
            
            while cleanContent.hasSuffix("-") || cleanContent.hasSuffix("—") {
                cleanContent = String(cleanContent.dropLast()).trimmingCharacters(in: .whitespaces)
            }
            
            var formatted = "\"\(cleanContent)\""
            if let author = note.author {
                formatted += " - \(author)"
                if let bookTitle = note.bookTitle {
                    formatted += ", \(bookTitle)"
                    if let pageNumber = note.pageNumber {
                        formatted += ", p. \(pageNumber)"
                    }
                }
            }
            return formatted
        }
    }
}

// MARK: - Simple Filter Pill
struct FilterPill: View {
    let title: String
    let count: Int
    var icon: String? = nil
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text("(\(count))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .foregroundStyle(isActive ? .white : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassEffect(
                isActive ? 
                    .regular.tint(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)) :
                    .regular.tint(Color.white.opacity(0.05)),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive ?
                            Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4) :
                            Color.white.opacity(0.1),
                        lineWidth: 0.5
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
    }
}