import SwiftUI
import UIKit

// MARK: - Notes View
struct NotesView: View {
    @EnvironmentObject var notesViewModel: NotesViewModel
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var selectedFilter: NoteType? = nil
    @State private var showingAddNote = false
    @State private var isSelectionMode = false
    @State private var selectedNotes: Set<UUID> = []
    @State private var showingFilterOptions = false
    @State private var showingEditSheet = false
    @State private var noteToEdit: Note? = nil
    @State private var openOptionsNoteId: UUID? = nil
    
    var filteredNotes: [Note] {
        var filtered = notesViewModel.notes
        
        // Apply type filter
        if let selectedFilter = selectedFilter {
            filtered = filtered.filter { $0.type == selectedFilter }
        }
        
        
        return filtered.sorted { $0.dateCreated > $1.dateCreated }
    }
    
    var body: some View {
        ZStack {
            // Midnight scholar background
            Color(red: 0.11, green: 0.105, blue: 0.102) // #1C1B1A
                .ignoresSafeArea(.all)
            
            // Soft vignette effect
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.2)
                ]),
                center: .center,
                startRadius: 200,
                endRadius: 400
            )
            .ignoresSafeArea(.all)
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Selection mode header
                    if isSelectionMode {
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
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Filter chips at the top
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
                                        print("🔵 Long press detected on All filter")
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
                    .padding(.top, 20)
                    .popover(isPresented: $showingFilterOptions) {
                        FilterOptionsPopover(
                            isSelectionMode: $isSelectionMode,
                            selectedNotes: $selectedNotes,
                            filteredNotes: filteredNotes
                        )
                        .presentationCompactAdaptation(.popover)
                    }
                    
                    // Notes list
                    if filteredNotes.isEmpty {
                        // Empty state
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
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else {
                        // Notes layout
                        VStack(spacing: 20) {
                            ForEach(filteredNotes) { note in
                                NoteCard(
                                    note: note,
                                    isSelectionMode: isSelectionMode,
                                    isSelected: selectedNotes.contains(note.id),
                                    onSelectionToggle: {
                                        if selectedNotes.contains(note.id) {
                                            selectedNotes.remove(note.id)
                                        } else {
                                            selectedNotes.insert(note.id)
                                        }
                                    },
                                    openOptionsNoteId: $openOptionsNoteId
                                )
                                .id(note.id) // Add stable ID for tracking
                                .zIndex(openOptionsNoteId == note.id ? 1 : 0) // Higher z-index when showing options
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 1.05).combined(with: .opacity)
                                ))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !isSelectionMode {
                                        Button(role: .destructive) {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                notesViewModel.deleteNote(note)
                                                HapticManager.shared.success()
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20) // Space for content
                    }
                }
            }
            
            // Floating delete button when in selection mode
            if isSelectionMode && !selectedNotes.isEmpty {
                VStack {
                    Spacer()
                    
                    Button(action: {
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
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                            Text("Delete (\(selectedNotes.count))")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background {
                            Capsule()
                                .fill(Color.red)
                                .shadow(color: .red.opacity(0.3), radius: 10, y: 4)
                        }
                    }
                    .padding(.bottom, 90) // Above tab bar
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                    removal: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom))
                ))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedNotes.count)
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
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: filteredNotes.count)
        .overlay {
            if showingAddNote {
                LiquidEditSheet(
                    noteType: .note,
                    onSave: { newNote in
                        notesViewModel.addNote(newNote)
                    },
                    onDismiss: {
                        showingAddNote = false
                    }
                )
                .environmentObject(libraryViewModel)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: 50)),
                    removal: .scale(scale: 0.95, anchor: .bottom)
                        .combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingAddNote)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ResetNotesFilter"))) { _ in
            // Reset filter to show all notes when coming from command bar
            selectedFilter = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EditNote"))) { notification in
            if let note = notification.object as? Note {
                noteToEdit = note
                showingEditSheet = true
                notesViewModel.isEditingNote = true
            }
        }
        .overlay {
            if showingEditSheet, let noteToEdit = noteToEdit {
                LiquidEditSheet(
                    note: noteToEdit,
                    noteType: noteToEdit.type,
                    onSave: { updatedNote in
                        notesViewModel.updateNote(noteToEdit, with: updatedNote)
                        showingEditSheet = false
                        self.noteToEdit = nil
                        notesViewModel.isEditingNote = false
                    },
                    onDismiss: {
                        showingEditSheet = false
                        self.noteToEdit = nil
                        notesViewModel.isEditingNote = false
                    }
                )
                .environmentObject(libraryViewModel)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: 50)),
                    removal: .scale(scale: 0.95, anchor: .bottom)
                        .combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingEditSheet)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), lineWidth: 1)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        }
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Note Card
struct NoteCard: View {
    let note: Note
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    @State private var isPressed = false
    @State private var showingOptions = false
    @Binding var openOptionsNoteId: UUID?
    
    init(note: Note, isSelectionMode: Bool = false, isSelected: Bool = false, onSelectionToggle: @escaping () -> Void = {}, openOptionsNoteId: Binding<UUID?> = .constant(nil)) {
        self.note = note
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.onSelectionToggle = onSelectionToggle
        self._openOptionsNoteId = openOptionsNoteId
    }
    
    var body: some View {
        ZStack {
            if note.type == .quote {
                QuoteCard(note: note, isPressed: $isPressed, showingOptions: $showingOptions)
            } else {
                RegularNoteCard(note: note, isPressed: $isPressed, showingOptions: $showingOptions)
            }
            
            // Selection overlay
            if isSelectionMode {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(isSelected ? 0.3 : 0.1))
                    .overlay {
                        HStack {
                            Spacer()
                            VStack {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.55, blue: 0.26) : .white.opacity(0.6))
                                    .padding(16)
                                Spacer()
                            }
                        }
                    }
                    .allowsHitTesting(true)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            HapticManager.shared.lightTap()
                            onSelectionToggle()
                        }
                    }
            }
        }
        .onChange(of: showingOptions) { _, newValue in
            if newValue {
                openOptionsNoteId = note.id
            } else if openOptionsNoteId == note.id {
                openOptionsNoteId = nil
            }
        }
        .opacity(isSelectionMode && !isSelected ? 0.6 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Quote Card (Literary Design)
struct QuoteCard: View {
    let note: Note
    @Binding var isPressed: Bool
    @Binding var showingOptions: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    var firstLetter: String {
        String(note.content.prefix(1))
    }
    
    var restOfContent: String {
        String(note.content.dropFirst())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Large transparent opening quote
            Text("\u{201C}")
                .font(.custom("Georgia", size: 80))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                .offset(x: -10, y: 20)
                .frame(height: 0)
            
            // Quote content with drop cap
            HStack(alignment: .top, spacing: 0) {
                // Drop cap
                Text(firstLetter)
                    .font(.custom("Georgia", size: 56))
                    .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102))
                    .padding(.trailing, 4)
                    .offset(y: -8)
                
                // Rest of quote
                Text(restOfContent)
                    .font(.custom("Georgia", size: 24))
                    .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102))
                    .lineSpacing(11) // Line height 1.5
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(.top, 20)
            
            // Attribution section
            VStack(alignment: .leading, spacing: 12) {
                // Thin horizontal rule with gradient
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.1), location: 0),
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(1.0), location: 0.5),
                        .init(color: Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.1), location: 1.0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .padding(.top, 20)
                
                // Attribution text - reordered: Author -> Source -> Page
                VStack(alignment: .leading, spacing: 6) {
                    if let author = note.author {
                        Text(author.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.8))
                    }
                    
                    if let bookTitle = note.bookTitle {
                        Text(bookTitle.uppercased())
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .kerning(1.2)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.6))
                    }
                    
                    if let pageNumber = note.pageNumber {
                        Text("PAGE \(pageNumber)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(Color(red: 0.11, green: 0.105, blue: 0.102).opacity(0.5))
                    }
                }
            }
        }
        .padding(32) // Generous padding
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.96)) // #FAF8F5
                .shadow(color: Color(red: 0.8, green: 0.7, blue: 0.6).opacity(0.15), radius: 12, x: 0, y: 4)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: .infinity) {
            print("🔵 QuoteCard: Long press detected")
            HapticManager.shared.mediumImpact()
            showingOptions = true
            print("🔵 QuoteCard: showingOptions set to true")
        }
        .overlay {
            // Show options menu with higher Z-order
            if showingOptions {
                GlassOptionsMenu(
                    note: note,
                    isPresented: $showingOptions
                )
                .environmentObject(notesViewModel)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .bottom)
                        .combined(with: .opacity)
                ))
                .zIndex(2) // Higher Z-order
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingOptions)
    }
}

// MARK: - Regular Note Card
struct RegularNoteCard: View {
    let note: Note
    @Binding var isPressed: Bool
    @Binding var showingOptions: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Date
                Text(note.formattedDate)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                
                Spacer()
                
                // Note indicator
                Image(systemName: "note.text")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
            }
            
            // Content
            Text(note.content)
                .font(.custom("SF Pro Display", size: 16))
                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(4)
            
            // Book info (if available)
            if note.bookTitle != nil || note.author != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .background(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1))
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 8) {
                        Text("re:")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if let bookTitle = note.bookTitle {
                                Text(bookTitle)
                                    .font(.system(size: 14, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.9))
                            }
                            
                            HStack(spacing: 8) {
                                if let author = note.author {
                                    Text(author)
                                        .font(.system(size: 12, design: .default))
                                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                                }
                                
                                if let pageNumber = note.pageNumber {
                                    Text("• p. \(pageNumber)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3)) {
                    isPressed = false
                }
            }
            HapticManager.shared.lightTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, maximumDistance: .infinity) {
            HapticManager.shared.mediumImpact()
            showingOptions = true
        }
        .overlay {
            // Show options menu with higher Z-order
            if showingOptions {
                GlassOptionsMenu(
                    note: note,
                    isPresented: $showingOptions
                )
                .environmentObject(notesViewModel)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .bottom)
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.95, anchor: .bottom)
                        .combined(with: .opacity)
                ))
                .zIndex(2) // Higher Z-order
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showingOptions)
    }
}

// MARK: - Quote Options Popover
struct QuoteOptionsPopover: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Share as image
            Button(action: shareAsImage) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                    Text("Share as Image")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Copy text
            Button(action: copyText) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                    Text("Copy Quote")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Edit
            Button(action: edit) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                    Text("Edit")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Delete
            Button(action: deleteNote) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                    Text("Delete")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 200)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    private func shareAsImage() {
        HapticManager.shared.lightTap()
        // TODO: Generate beautiful image with quote
        dismiss()
    }
    
    private func copyText() {
        HapticManager.shared.lightTap()
        UIPasteboard.general.string = note.content
        dismiss()
    }
    
    private func edit() {
        HapticManager.shared.lightTap()
        // TODO: Open edit sheet
        dismiss()
    }
    
    private func deleteNote() {
        HapticManager.shared.warning()
        notesViewModel.deleteNote(note)
        dismiss()
    }
}

// MARK: - Note Options Popover
struct NoteOptionsPopover: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Copy text
            Button(action: copyText) {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                    Text("Copy Note")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Edit
            Button(action: edit) {
                HStack {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                    Text("Edit")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Delete
            Button(action: deleteNote) {
                HStack {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                    Text("Delete")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 200)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    private func copyText() {
        HapticManager.shared.lightTap()
        var textToCopy = note.content
        if let bookTitle = note.bookTitle {
            textToCopy += "\n\n— from \(bookTitle)"
            if let author = note.author {
                textToCopy += " by \(author)"
            }
        }
        UIPasteboard.general.string = textToCopy
        dismiss()
    }
    
    private func edit() {
        HapticManager.shared.lightTap()
        // Find the parent view and trigger edit mode
        NotificationCenter.default.post(name: Notification.Name("EditNote"), object: note)
        dismiss()
    }
    
    private func deleteNote() {
        HapticManager.shared.warning()
        notesViewModel.deleteNote(note)
        dismiss()
    }
}

// MARK: - Filter Options Popover
struct FilterOptionsPopover: View {
    @Binding var isSelectionMode: Bool
    @Binding var selectedNotes: Set<UUID>
    let filteredNotes: [Note]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var notesViewModel: NotesViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Simple Select Multiple
            if !isSelectionMode {
                Button(action: enterSelectionMode) {
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
                
                Divider()
                    .background(Color.white.opacity(0.1))
            }
            
            // Select All Visible
            Button(action: selectAllVisible) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text("Select All Visible (\(filteredNotes.count))")
                        .font(.system(size: 15))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Select by Type
            Menu {
                ForEach(NoteType.allCases, id: \.self) { type in
                    Button(action: { selectByType(type) }) {
                        Label("\(type.displayName)s", systemImage: type.icon)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "doc.text.below.ecg")
                        .font(.system(size: 16))
                    Text("Select by Type")
                        .font(.system(size: 15))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Select by Date
            Menu {
                Button(action: { selectByDate(.today) }) {
                    Label("Today", systemImage: "calendar")
                }
                Button(action: { selectByDate(.lastWeek) }) {
                    Label("Last 7 Days", systemImage: "calendar.badge.clock")
                }
                Button(action: { selectByDate(.lastMonth) }) {
                    Label("Last 30 Days", systemImage: "calendar.circle")
                }
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                    Text("Select by Date")
                        .font(.system(size: 15))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            if isSelectionMode && !selectedNotes.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Deselect All
                Button(action: deselectAll) {
                    HStack {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16))
                        Text("Deselect All")
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Delete Selected
                Button(action: deleteSelected) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                        Text("Delete Selected (\(selectedNotes.count))")
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            
            if isSelectionMode {
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Cancel Selection Mode
                Button(action: cancelSelection) {
                    HStack {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 16))
                        Text("Exit Selection Mode")
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(width: 260)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 10)
    }
    
    enum DateRange {
        case today, lastWeek, lastMonth
    }
    
    private func enterSelectionMode() {
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
        }
        dismiss()
    }
    
    private func selectAllVisible() {
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
            selectedNotes = Set(filteredNotes.map { $0.id })
        }
        dismiss()
    }
    
    private func selectByType(_ type: NoteType) {
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
            let notesOfType = notesViewModel.notes.filter { $0.type == type }
            selectedNotes = Set(notesOfType.map { $0.id })
        }
        dismiss()
    }
    
    private func selectByDate(_ range: DateRange) {
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isSelectionMode = true
            let calendar = Calendar.current
            let now = Date()
            
            let startDate: Date
            switch range {
            case .today:
                startDate = calendar.startOfDay(for: now)
            case .lastWeek:
                startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .lastMonth:
                startDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            }
            
            let notesInRange = notesViewModel.notes.filter { note in
                note.dateCreated >= startDate
            }
            selectedNotes = Set(notesInRange.map { $0.id })
        }
        dismiss()
    }
    
    private func deselectAll() {
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedNotes.removeAll()
        }
    }
    
    private func deleteSelected() {
        HapticManager.shared.warning()
        for noteId in selectedNotes {
            if let note = notesViewModel.notes.first(where: { $0.id == noteId }) {
                notesViewModel.deleteNote(note)
            }
        }
        selectedNotes.removeAll()
        isSelectionMode = false
        dismiss()
    }
    
    private func cancelSelection() {
        HapticManager.shared.lightTap()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedNotes.removeAll()
            isSelectionMode = false
        }
        dismiss()
    }
}

// MARK: - Add Note Sheet
struct AddNoteSheet: View {
    let onSave: (Note) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var noteType: NoteType = .note
    @State private var content = ""
    @State private var bookTitle = ""
    @State private var author = ""
    @State private var pageNumber = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.11, green: 0.105, blue: 0.102)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Type picker
                    HStack(spacing: 12) {
                        ForEach(NoteType.allCases, id: \.self) { type in
                            Button(action: { noteType = type }) {
                                HStack(spacing: 8) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Text(type.displayName)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundStyle(noteType == type ? .white : .white.opacity(0.7))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background {
                                    if noteType == type {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4), lineWidth: 1)
                                            }
                                    } else {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.white.opacity(0.05))
                                    }
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: noteType)
                        }
                        
                        Spacer()
                    }
                    
                    // Content input
                    VStack(alignment: .leading, spacing: 8) {
                        Text(noteType == .quote ? "Quote" : "Note")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                        
                        TextField(noteType == .quote ? "Enter quote..." : "Enter note...", text: $content, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(.system(size: 16, design: .serif))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    }
                            }
                            .lineLimit(5...)
                    }
                    
                    // Optional book info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Book Information (Optional)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                        
                        VStack(spacing: 12) {
                            TextField("Book title", text: $bookTitle)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                }
                            
                            TextField("Author", text: $author)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                }
                            
                            TextField("Page number", text: $pageNumber)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                }
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Add \(noteType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                    .disabled(content.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        var finalContent = content.trimmingCharacters(in: .whitespaces)
        var finalAuthor = author.isEmpty ? nil : author
        var finalBookTitle = bookTitle.isEmpty ? nil : bookTitle
        var finalPageNumber = pageNumber.isEmpty ? nil : Int(pageNumber)
        
        // For notes, check if there's attribution in the content itself
        if noteType == .note && finalAuthor == nil && finalBookTitle == nil {
            // Check for pattern: "content - Author, Book Title"
            let attributionPattern = "^(.+?)\\s*-\\s*([^,]+)(?:,\\s*(.+))?$"
            
            if let regex = try? NSRegularExpression(pattern: attributionPattern, options: [.dotMatchesLineSeparators]) {
                let originalContent = finalContent
                let range = NSRange(location: 0, length: originalContent.utf16.count)
                if let match = regex.firstMatch(in: originalContent, options: [], range: range) {
                    // Check if this looks like attribution (not just a dash in the middle of content)
                    if let contentRange = Range(match.range(at: 1), in: originalContent),
                       let authorRange = Range(match.range(at: 2), in: originalContent) {
                        
                        let possibleContent = String(originalContent[contentRange]).trimmingCharacters(in: .whitespaces)
                        let possibleAuthor = String(originalContent[authorRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Only parse as attribution if author part looks like a name
                        if possibleAuthor.split(separator: " ").count <= 4 && !possibleAuthor.contains(".") {
                            finalContent = possibleContent
                            finalAuthor = possibleAuthor
                            
                            if match.range(at: 3).location != NSNotFound,
                               let bookRange = Range(match.range(at: 3), in: originalContent) {
                                finalBookTitle = String(originalContent[bookRange]).trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
            }
        }
        
        let newNote = Note(
            type: noteType,
            content: finalContent,
            bookTitle: finalBookTitle,
            author: finalAuthor,
            pageNumber: finalPageNumber,
            dateCreated: Date()
        )
        
        HapticManager.shared.success()
        onSave(newNote)
        dismiss()
    }
}


// MARK: - Token-Based Edit Note Sheet
struct EditNoteSheet: View {
    let note: Note
    let onSave: (Note) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @State private var fullText = ""
    @State private var hasChanges = false
    @State private var animateIn = false
    @FocusState private var focusedField: TokenType?
    @State private var dragOffset = CGSize.zero
    @State private var noteType: NoteType
    
    enum TokenType: CaseIterable {
        case quote, bookTitle, author, pageNumber
    }
    
    init(note: Note, onSave: @escaping (Note) -> Void) {
        self.note = note
        self.onSave = onSave
        self._noteType = State(initialValue: note.type)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Clean floating card - no background dimming
            VStack(spacing: 0) {
                // Simple handle - no curved shape
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 3)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                
                // Single flowing text editor
                InlineTokenEditor(
                    fullText: $fullText,
                    noteType: $noteType,
                    onTextChange: { checkForChanges() }
                )
                .focused($focusedField, equals: .quote)
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 2)
            }
            .offset(y: animateIn ? 0 : 400)
            .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismissEditor()
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            
            // Floating save button
            if hasChanges {
                HStack {
                    Spacer()
                    
                    Button(action: saveNote) {
                        HStack(spacing: 8) {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background {
                            Capsule()
                                .fill(Color(red: 1.0, green: 0.55, blue: 0.26))
                        }
                        .shadow(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), radius: 8)
                    }
                    
                    Spacer()
                }
                .padding(.top, 16)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 1.2).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal, 16)
        .presentationDetents([.height(UIScreen.main.bounds.height * 0.5)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
        .interactiveDismissDisabled(hasChanges)
        .onAppear {
            // Initialize with combined text
            buildFullText()
            
            // Check if content is a quote format and auto-detect type
            if note.type == .note && note.content.isEmpty == false {
                let intent = CommandParser.parse(note.content)
                if case .createQuote = intent {
                    noteType = .quote
                    // Parse quote content if needed
                    let parsed = CommandParser.parseQuote(note.content)
                    if let author = parsed.author {
                        fullText = "\(parsed.content), — \(author)"
                    } else {
                        fullText = parsed.content
                    }
                }
            }
            
            // Animate in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animateIn = true
            }
            
            // Focus text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                focusedField = .quote
            }
        }
    }
    
    private func checkForChanges() {
        let originalFullText = buildOriginalFullText()
        
        withAnimation(.spring(response: 0.3)) {
            hasChanges = fullText != originalFullText
        }
    }
    
    private func buildFullText() {
        var components: [String] = []
        
        // Add main content - for quotes, remove quotation marks
        var content = note.content
        if noteType == .quote {
            // Remove quotation marks if present
            if (content.hasPrefix("\"") && content.hasSuffix("\"")) ||
               (content.hasPrefix("\u{201C}") && content.hasSuffix("\u{201D}")) {
                content = String(content.dropFirst().dropLast())
            }
        }
        
        if !content.isEmpty {
            components.append(content)
        }
        
        // Add author on new line for quotes
        if let author = note.author, !author.isEmpty {
            if noteType == .quote {
                components.append("\n\n— \(author)")
            } else {
                components.append(", — \(author)")
            }
        }
        
        // Add book on new line for quotes
        if let bookTitle = note.bookTitle, !bookTitle.isEmpty {
            if noteType == .quote && note.author != nil {
                components.append("\n\(bookTitle)")
            } else {
                components.append(", from \(bookTitle)")
            }
        }
        
        // Add page
        if let pageNumber = note.pageNumber {
            if noteType == .quote && (note.author != nil || note.bookTitle != nil) {
                components.append("\np. \(pageNumber)")
            } else {
                components.append(", p. \(pageNumber)")
            }
        }
        
        fullText = components.joined(separator: "")
    }
    
    private func buildOriginalFullText() -> String {
        var components: [String] = []
        
        // Add main content
        if !note.content.isEmpty {
            components.append(note.content)
        }
        
        // Add author if present
        if let author = note.author, !author.isEmpty {
            components.append("— \(author)")
        }
        
        // Add book if present
        if let bookTitle = note.bookTitle, !bookTitle.isEmpty {
            components.append("from \(bookTitle)")
        }
        
        // Add page if present
        if let pageNumber = note.pageNumber {
            components.append("p. \(pageNumber)")
        }
        
        return components.joined(separator: ", ")
    }
    
    private func saveNote() {
        let parsedComponents = parseFullText(fullText)
        
        // Debug print
        print("📝 Saving Quote:")
        print("  Full Text: \(fullText)")
        print("  Parsed Content: \(parsedComponents.content)")
        print("  Parsed Author: \(parsedComponents.author ?? "nil")")
        print("  Parsed Book: \(parsedComponents.bookTitle ?? "nil")")
        print("  Parsed Page: \(parsedComponents.pageNumber?.description ?? "nil")")
        
        // Try to match with a book in the library
        var matchedBook: Book? = nil
        if let bookTitle = parsedComponents.bookTitle {
            print("🔍 Attempting to match book title: '\(bookTitle)' with author: '\(parsedComponents.author ?? "nil")'")
            matchedBook = libraryViewModel.findMatchingBook(title: bookTitle, author: parsedComponents.author)
            if let book = matchedBook {
                print("✅ Found matching book: '\(book.title)' by '\(book.author)'")
            } else {
                print("❌ No matching book found in library")
            }
        }
        
        let updatedNote = Note(
            type: noteType,
            content: parsedComponents.content,
            bookId: matchedBook?.localId,
            bookTitle: matchedBook?.title ?? parsedComponents.bookTitle,
            author: matchedBook?.author ?? parsedComponents.author,
            pageNumber: parsedComponents.pageNumber,
            dateCreated: note.dateCreated,
            id: note.id
        )
        
        HapticManager.shared.success()
        onSave(updatedNote)
        dismissEditor()
    }
    
    private func parseFullText(_ text: String) -> (content: String, author: String?, bookTitle: String?, pageNumber: Int?) {
        var workingText = text
        var author: String? = nil
        var bookTitle: String? = nil
        var pageNumber: Int? = nil
        
        // First, check if this is a quote format: "content" author, book, page
        if noteType == .quote {
            print("🔍 Attempting to parse quote from: \(text)")
            
            // Debug: Check what quote characters we have
            if let firstChar = text.first {
                print("📊 First character: '\(firstChar)' (Unicode: U+\(String(format: "%04X", firstChar.unicodeScalars.first!.value)))")
            }
            
            // Try multiple quote patterns - ORDER MATTERS!
            let quotePatterns = [
                "^\"(.+?)\"\\s*(.+)$",                          // Regular double quotes (ASCII 34)
                "^[\u{201C}](.+?)[\u{201D}]\\s*(.+)$",         // Smart quotes left and right
                "^'(.+?)'\\s*(.+)$",                            // Single quotes
                "^[\u{2018}](.+?)[\u{2019}]\\s*(.+)$"          // Smart single quotes
            ]
            
            for (index, pattern) in quotePatterns.enumerated() {
                print("🧪 Trying pattern \(index + 1): \(pattern)")
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                    let range = NSRange(location: 0, length: text.utf16.count)
                    if let match = regex.firstMatch(in: text, options: [], range: range) {
                        if let contentRange = Range(match.range(at: 1), in: text),
                           let attributionRange = Range(match.range(at: 2), in: text) {
                            // Extract the quote content (without quotes)
                            let quoteContent = String(text[contentRange]).trimmingCharacters(in: .whitespaces)
                            let attribution = String(text[attributionRange]).trimmingCharacters(in: .whitespaces)
                            
                            print("✅ Matched! Content: '\(quoteContent)', Attribution: '\(attribution)'")
                            
                            // Parse the attribution (e.g., "Seneca, On the Shortness of Life, pg 30")
                            let parts = attribution.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            
                            if parts.count >= 1 {
                                author = parts[0]
                            }
                            if parts.count >= 2 {
                                bookTitle = parts[1]
                            }
                            if parts.count >= 3 {
                                let pageStr = parts[2]
                                // Extract page number from strings like "pg 30", "p. 30", "page 30"
                                if let pageMatch = pageStr.range(of: #"\d+"#, options: .regularExpression) {
                                    pageNumber = Int(pageStr[pageMatch])
                                }
                            }
                            
                            print("📚 Parsed - Author: \(author ?? "nil"), Book: \(bookTitle ?? "nil"), Page: \(pageNumber?.description ?? "nil")")
                            
                            return (content: quoteContent, author: author, bookTitle: bookTitle, pageNumber: pageNumber)
                        }
                    }
                }
            }
            
            print("❌ No quote pattern matched")
        }
        
        // If not a quote format or parsing failed, continue with original parsing
        // Extract page numbers (p. 123, page 123, pg 30)
        let pagePatterns = [
            "p\\.\\s*(\\d+)",
            "page\\s+(\\d+)",
            "pg\\s+(\\d+)",
            "PAGE\\s+(\\d+)"
        ]
        
        for pattern in pagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: workingText, range: NSRange(workingText.startIndex..., in: workingText)),
               let pageRange = Range(match.range(at: 1), in: workingText) {
                pageNumber = Int(String(workingText[pageRange]))
                // Remove the page reference from text
                workingText = regex.stringByReplacingMatches(in: workingText, range: NSRange(workingText.startIndex..., in: workingText), withTemplate: "")
                break
            }
        }
        
        // Extract book titles (from "Book Title")
        let bookPatterns = [
            "from \"([^\"]+)\"",
            "from ([^,]+)",
            "in \"([^\"]+)\"",
            "in ([^,]+)"
        ]
        
        for pattern in bookPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: workingText, range: NSRange(workingText.startIndex..., in: workingText)),
               let titleRange = Range(match.range(at: 1), in: workingText) {
                bookTitle = String(workingText[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                // Remove the book reference from text
                workingText = regex.stringByReplacingMatches(in: workingText, range: NSRange(workingText.startIndex..., in: workingText), withTemplate: "")
                break
            }
        }
        
        // Extract author (— Author Name) and check for book on next line
        let authorPatterns = [
            "— ([^\\n]+)",
            "—([^\\n]+)"
        ]
        
        for pattern in authorPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: workingText, range: NSRange(workingText.startIndex..., in: workingText)),
               let authorRange = Range(match.range(at: 1), in: workingText) {
                let authorLine = String(workingText[authorRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check if there's a book title and/or page on the next lines after the author
                let afterAuthorIndex = match.range.upperBound
                if afterAuthorIndex < workingText.count {
                    let remainingText = String(workingText.suffix(from: workingText.index(workingText.startIndex, offsetBy: afterAuthorIndex)))
                    let lines = remainingText.split(separator: "\n", maxSplits: 3).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    
                    var linesToRemove: [String] = []
                    
                    // Check first line after author for book title
                    if lines.count > 0 && !lines[0].isEmpty {
                        let firstLine = lines[0]
                        // Check if it's a page number
                        if firstLine.lowercased().hasPrefix("p.") || 
                           firstLine.lowercased().hasPrefix("page") || 
                           firstLine.lowercased().hasPrefix("pg") {
                            // Extract page number
                            if let pageMatch = firstLine.range(of: #"\d+"#, options: .regularExpression) {
                                pageNumber = Int(firstLine[pageMatch])
                            }
                            linesToRemove.append(firstLine)
                        } else if !firstLine.contains("—") && !firstLine.contains("\u{201D}") {
                            // It's a book title
                            bookTitle = firstLine
                            linesToRemove.append(firstLine)
                            
                            // Check if there's a page number on the next line
                            if lines.count > 1 && !lines[1].isEmpty {
                                let secondLine = lines[1]
                                if secondLine.lowercased().hasPrefix("p.") || 
                                   secondLine.lowercased().hasPrefix("page") || 
                                   secondLine.lowercased().hasPrefix("pg") {
                                    if let pageMatch = secondLine.range(of: #"\d+"#, options: .regularExpression) {
                                        pageNumber = Int(secondLine[pageMatch])
                                    }
                                    linesToRemove.append(secondLine)
                                }
                            }
                        }
                    }
                    
                    // Remove author and any additional lines we found
                    var removeString = "— \(authorLine)"
                    for line in linesToRemove {
                        removeString += "\n\(line)"
                    }
                    
                    if let fullRange = workingText.range(of: removeString) {
                        workingText.removeSubrange(fullRange)
                    } else if let fullRange = workingText.range(of: "—\(authorLine)") {
                        // Try without space
                        workingText.removeSubrange(fullRange)
                    }
                    
                    author = authorLine
                    break
                }
                
                // Just author, no book on next line
                author = authorLine
                // Remove the author reference from text
                workingText = regex.stringByReplacingMatches(in: workingText, range: NSRange(workingText.startIndex..., in: workingText), withTemplate: "")
                break
            }
        }
        
        // Clean up remaining content
        var content = workingText
            .replacingOccurrences(of: ", ,", with: ",")
            .replacingOccurrences(of: ",,", with: ",")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        
        // For quotes, ensure we don't have quotation marks in the content
        if noteType == .quote {
            if (content.hasPrefix("\"") && content.hasSuffix("\"")) ||
               (content.hasPrefix("\u{201C}") && content.hasSuffix("\u{201D}")) {
                content = String(content.dropFirst().dropLast())
            }
        } else if noteType == .note && author == nil && bookTitle == nil {
            // For notes, check if there's attribution in the content itself
            // Check for pattern: "content - Author, Book Title"
            let attributionPattern = "^(.+?)\\s*-\\s*([^,]+)(?:,\\s*(.+))?$"
            
            if let regex = try? NSRegularExpression(pattern: attributionPattern, options: [.dotMatchesLineSeparators]) {
                let range = NSRange(location: 0, length: content.utf16.count)
                if let match = regex.firstMatch(in: content, options: [], range: range) {
                    // Check if this looks like attribution (not just a dash in the middle of content)
                    if let contentRange = Range(match.range(at: 1), in: content),
                       let authorRange = Range(match.range(at: 2), in: content) {
                        
                        let possibleContent = String(content[contentRange]).trimmingCharacters(in: .whitespaces)
                        let possibleAuthor = String(content[authorRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Only parse as attribution if author part looks like a name
                        if possibleAuthor.split(separator: " ").count <= 4 && !possibleAuthor.contains(".") {
                            content = possibleContent
                            author = possibleAuthor
                            
                            if match.range(at: 3).location != NSNotFound,
                               let bookRange = Range(match.range(at: 3), in: text) {
                                bookTitle = String(text[bookRange]).trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
            }
        }
        
        return (content: content, author: author, bookTitle: bookTitle, pageNumber: pageNumber)
    }
    
    private func dismissEditor() {
        focusedField = nil
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            animateIn = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            dismiss()
        }
    }
}

// MARK: - Inline Token Editor
struct InlineTokenEditor: View {
    @Binding var fullText: String
    @Binding var noteType: NoteType
    let onTextChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Type icon
            HStack {
                Image(systemName: noteType == .quote ? "quote.bubble.fill" : "note.text.badge.plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                
                Spacer()
            }
            
            // Flowing text editor with token recognition
            InlineTokenTextEditor(
                text: $fullText,
                placeholder: noteType == .quote ? "Enter quote..." : "Enter note...",
                onTextChange: {
                    // Check if text looks like a quote
                    if fullText.contains("\"") || fullText.contains("\u{201C}") {
                        noteType = .quote
                    } else if !fullText.isEmpty {
                        noteType = .note
                    }
                    onTextChange()
                }
            )
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Inline Token Text Editor
struct InlineTokenTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let onTextChange: () -> Void
    @State private var textHeight: CGFloat = 120
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .font(.custom("Georgia", size: 20))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.horizontal, 4)
            }
            
            // Main text editor
            TextEditor(text: $text)
                .font(.custom("Georgia", size: 20))
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .lineSpacing(6)
                .frame(minHeight: 120)
                .onChange(of: text) { oldValue, newValue in
                    // Auto-convert em-dash to long em-dash
                    if newValue.contains("–") {
                        text = newValue.replacingOccurrences(of: "–", with: "—")
                    }
                    onTextChange()
                }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.3))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }
        }
    }
}

// MARK: - Spotlight-Style Main Field
struct SpotlightMainField: View {
    @Binding var text: String
    let noteType: NoteType
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quote/Note icon (top left like Spotlight)
            HStack {
                Image(systemName: noteType == .quote ? "quote.bubble.fill" : "note.text.badge.plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                
                Spacer()
            }
            
            // Main text field
            if isEditing {
                TextEditor(text: $text)
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .foregroundStyle(.primary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .lineSpacing(2)
                    .frame(minHeight: 80)
                    .onChange(of: text) { oldValue, newValue in
                        // Auto-convert em-dash to long em-dash
                        if newValue.contains("–") {
                            text = newValue.replacingOccurrences(of: "–", with: "—")
                        }
                    }
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    Text(text.isEmpty ? (noteType == .quote ? "Enter quote..." : "Enter note...") : text)
                        .font(.system(size: 18, weight: .regular, design: .default))
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: 80, alignment: .topLeading)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isEditing ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4) : Color.clear, lineWidth: 2)
                }
        }
        .scaleEffect(isEditing ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Spotlight-Style Token Pills
struct SpotlightTokensView: View {
    @Binding var bookTitle: String
    @Binding var author: String
    @Binding var pageNumber: String
    @Binding var activeToken: EditNoteSheet.TokenType?
    let onTokenChange: () -> Void
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author pill (like "Heraclitus" in the screenshot)
            if !author.isEmpty || activeToken == .author {
                SpotlightTokenPill(
                    icon: "person.fill",
                    text: $author,
                    placeholder: "Author",
                    isEditing: activeToken == .author,
                    onEdit: { activeToken = .author },
                    onEndEdit: onTokenChange
                )
            }
            
            // Book and Page pills in one row (like bottom row in screenshot)
            HStack(spacing: 12) {
                if !bookTitle.isEmpty || activeToken == .bookTitle {
                    SpotlightTokenPill(
                        icon: "book.fill",
                        text: $bookTitle,
                        placeholder: "Book",
                        isEditing: activeToken == .bookTitle,
                        onEdit: { activeToken = .bookTitle },
                        onEndEdit: onTokenChange
                    )
                }
                
                if !pageNumber.isEmpty || activeToken == .pageNumber {
                    SpotlightTokenPill(
                        icon: "doc.text.fill",
                        text: $pageNumber,
                        placeholder: "Page",
                        isEditing: activeToken == .pageNumber,
                        onEdit: { activeToken = .pageNumber },
                        onEndEdit: onTokenChange
                    )
                    .keyboardType(.numberPad)
                }
                
                Spacer()
            }
            
            // Add token buttons (only show when not editing anything)
            if activeToken == nil {
                HStack(spacing: 8) {
                    if author.isEmpty {
                        AddSpotlightTokenButton(icon: "person.fill", label: "Author") {
                            activeToken = .author
                        }
                    }
                    
                    if bookTitle.isEmpty {
                        AddSpotlightTokenButton(icon: "book.fill", label: "Book") {
                            activeToken = .bookTitle
                        }
                    }
                    
                    if pageNumber.isEmpty {
                        AddSpotlightTokenButton(icon: "doc.text.fill", label: "Page") {
                            activeToken = .pageNumber
                        }
                    }
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: activeToken)
    }
}

// MARK: - Spotlight Token Pill
struct SpotlightTokenPill: View {
    let icon: String
    @Binding var text: String
    let placeholder: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26))
                .frame(width: 16)
            
            // Text
            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    Text(text.isEmpty ? placeholder : text)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(isEditing ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4) : Color.clear, lineWidth: 1.5)
                }
        }
        .scaleEffect(isEditing ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Add Spotlight Token Button
struct AddSpotlightTokenButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(.quaternary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quote Token View
struct QuoteTokenView: View {
    @Binding var text: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                TextEditor(text: $text)
                    .font(.custom("Georgia", size: 22))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .lineSpacing(6)
                    .frame(minHeight: 120)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1.5)
                            }
                    }
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Quote mark
                        Text("\"")
                            .font(.custom("Georgia", size: 48))
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3))
                            .offset(x: -4, y: 8)
                            .frame(height: 0)
                        
                        // Quote text
                        Text(text.isEmpty ? "Tap to add quote..." : text)
                            .font(.custom("Georgia", size: 22))
                            .foregroundStyle(text.isEmpty ? 
                                Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4) :
                                Color(red: 0.98, green: 0.97, blue: 0.96)
                            )
                            .italic(text.isEmpty)
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.02))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .scaleEffect(isEditing ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Note Token View (for regular notes)
struct NoteTokenView: View {
    @Binding var text: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isEditing {
                TextEditor(text: $text)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .lineSpacing(4)
                    .frame(minHeight: 100)
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.3), lineWidth: 1.5)
                            }
                    }
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Note icon
                        HStack {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                            
                            Spacer()
                        }
                        
                        // Note text
                        Text(text.isEmpty ? "Tap to add note..." : text)
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .foregroundStyle(text.isEmpty ? 
                                Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.4) :
                                Color(red: 0.98, green: 0.97, blue: 0.96)
                            )
                            .italic(text.isEmpty)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.02))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .scaleEffect(isEditing ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Attribution Token View
struct AttributionTokenView: View {
    let icon: String
    @Binding var text: String
    let placeholder: String
    let isEditing: Bool
    let onEdit: () -> Void
    let onEndEdit: () -> Void
    var isSmall: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: isSmall ? 12 : 14, weight: .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.8))
                .frame(width: isSmall ? 16 : 18)
            
            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: isSmall ? 14 : 16, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                    .onSubmit {
                        onEndEdit()
                    }
            } else {
                Button(action: onEdit) {
                    Text(text.isEmpty ? placeholder : text)
                        .font(.system(size: isSmall ? 14 : 16, weight: .medium, design: .serif))
                        .foregroundStyle(text.isEmpty ? 
                            Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5) :
                            Color(red: 0.98, green: 0.97, blue: 0.96)
                        )
                        .italic(text.isEmpty)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, isSmall ? 12 : 16)
        .padding(.vertical, isSmall ? 6 : 10)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(isEditing ? 0.08 : 0.03))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(
                            isEditing ? 
                                Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.4) :
                                Color.white.opacity(0.2),
                            lineWidth: isEditing ? 1.5 : 1
                        )
                }
        }
        .scaleEffect(isEditing ? 1.05 : 1.0)
        .shadow(color: isEditing ? Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.2) : .clear, radius: 8)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
    }
}

// MARK: - Add Token Button
struct AddTokenButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.lightTap()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6))
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NotesView()
        .environmentObject(NotesViewModel())
}
