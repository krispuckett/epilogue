import SwiftUI

// Import is handled automatically in Swift for files in the same module

struct NotesView: View {
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    
    @State private var selectedFilter: NoteType? = nil
    @State private var isSelectionMode = false
    @State private var selectedNotes: Set<UUID> = []
    @State private var showingAddNote = false
    @State private var showingEditSheet = false
    @State private var noteToEdit: Note? = nil
    @State private var openOptionsNoteId: UUID? = nil
    @State private var showingFilterOptions = false
    
    @Namespace private var commandPaletteNamespace
    
    var filteredNotes: [Note] {
        var filtered = notesViewModel.notes
        
        if let selectedFilter = selectedFilter {
            filtered = filtered.filter { $0.type == selectedFilter }
        }
        
        return filtered.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Selection mode header
                if isSelectionMode {
                    selectionModeHeader
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Filter chips
                filterChipsView
                
                // Notes content
                if filteredNotes.isEmpty {
                    emptyStateView
                } else {
                    notesListView
                }
            }
            
            // Floating delete button
            if isSelectionMode && !selectedNotes.isEmpty {
                floatingDeleteButton
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetNotesFilter"))) { _ in
            selectedFilter = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EditNote"))) { notification in
            if let note = notification.object as? Note {
                noteToEdit = note
                notesViewModel.isEditingNote = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var selectionModeHeader: some View {
        HStack {
            Text("\(selectedNotes.count) selected")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isSelectionMode = false
                    selectedNotes.removeAll()
                }
            }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassEffect(.regular.tint(Color.white.opacity(0.05)), in: Rectangle())
    }
    
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All notes chip
                FilterChip(
                    title: "All (\(notesViewModel.notes.count))",
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            HapticManager.shared.mediumImpact()
                            showingFilterOptions = true
                        }
                )
                
                // Type-specific chips
                ForEach(NoteType.allCases, id: \.self) { type in
                    let count = notesViewModel.notes.filter { $0.type == type }.count
                    FilterChip(
                        title: "\(type.displayName) (\(count))",
                        icon: type.icon,
                        isSelected: selectedFilter == type,
                        action: { selectedFilter = selectedFilter == type ? nil : type }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                HapticManager.shared.mediumImpact()
                                selectedFilter = type
                                showingFilterOptions = true
                            }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .popover(isPresented: $showingFilterOptions) {
            FilterOptionsPopover(
                isSelectionMode: $isSelectionMode,
                selectedNotes: $selectedNotes,
                filteredNotes: filteredNotes
            )
            .presentationCompactAdaptation(.popover)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: selectedFilter?.icon ?? "note.text")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
            
            Text(selectedFilter == nil ? "No notes yet" : "No \(selectedFilter?.displayName.lowercased() ?? "notes") yet")
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
            
            Text("Tap + to add your first \(selectedFilter?.displayName.lowercased() ?? "note")")
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    private var notesListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredNotes) { note in
                    NoteCard(
                        note: note,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedNotes.contains(note.id),
                        onSelectionToggle: {
                            toggleSelection(for: note)
                        },
                        openOptionsNoteId: $openOptionsNoteId
                    )
                    .environmentObject(notesViewModel)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .scrollContentBackground(.hidden)
    }
    
    private var floatingDeleteButton: some View {
        VStack {
            Spacer()
            
            Button(action: deleteSelectedNotes) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                    Text("Delete (\(selectedNotes.count))")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .glassEffect(.regular.tint(Color.red.opacity(0.8)), in: Capsule())
                .shadow(color: .red.opacity(0.3), radius: 10, y: 4)
            }
            .padding(.bottom, 100)
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
            removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom))
        ))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedNotes.count)
    }
    
    // MARK: - Helper Methods
    
    private func toggleSelection(for note: Note) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if selectedNotes.contains(note.id) {
                selectedNotes.remove(note.id)
            } else {
                selectedNotes.insert(note.id)
            }
        }
    }
    
    private func deleteSelectedNotes() {
        HapticManager.shared.warning()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            for noteId in selectedNotes {
                if let note = notesViewModel.notes.first(where: { $0.id == noteId }) {
                    notesViewModel.deleteNote(note)
                }
            }
            selectedNotes.removeAll()
            isSelectionMode = false
        }
    }
    
    private func formatNoteForEditing(_ note: Note) -> String {
        switch note.type {
        case .note:
            return "note: \(note.content)"
        case .quote:
            var cleanContent = note.content.trimmingCharacters(in: .whitespaces)
            
            // Remove trailing dashes if they exist
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

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
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
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(
                isSelected ? 
                    .regular.tint(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3)) :
                    .regular.tint(Color.white.opacity(0.05)),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ?
                            Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4) :
                            Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Filter Options Popover
struct FilterOptionsPopover: View {
    @Binding var isSelectionMode: Bool
    @Binding var selectedNotes: Set<UUID>
    let filteredNotes: [Note]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: {
                isSelectionMode = true
                dismiss()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 16))
                    Text("Select Multiple")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            if filteredNotes.count > 0 {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                Button(action: {
                    selectedNotes = Set(filteredNotes.map { $0.id })
                    isSelectionMode = true
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.square")
                            .font(.system(size: 16))
                        Text("Select All")
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(width: 200)
        .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14)), in: RoundedRectangle(cornerRadius: 12))
        .presentationBackground(.clear)
    }
}