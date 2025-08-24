import SwiftUI

// MARK: - Note Card
struct NoteCard: View {
    let note: Note
    let isSelectionMode: Bool
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    @State private var isPressed = false
    @State private var showingOptions = false
    @Binding var openOptionsNoteId: UUID?
    @State private var cardRect: CGRect = .zero
    var onContextMenuRequest: ((Note, CGRect) -> Void)?
    @Environment(\.sizeCategory) var sizeCategory
    
    init(note: Note, isSelectionMode: Bool = false, isSelected: Bool = false, onSelectionToggle: @escaping () -> Void = {}, openOptionsNoteId: Binding<UUID?> = .constant(nil), onContextMenuRequest: ((Note, CGRect) -> Void)? = nil) {
        self.note = note
        self.isSelectionMode = isSelectionMode
        self.isSelected = isSelected
        self.onSelectionToggle = onSelectionToggle
        self._openOptionsNoteId = openOptionsNoteId
        self.onContextMenuRequest = onContextMenuRequest
    }
    
    var body: some View {
        ZStack {
            if note.type == .quote {
                QuoteCard(note: note, isPressed: $isPressed, showingOptions: $showingOptions)
            } else {
                RegularNoteCard(note: note, isPressed: $isPressed, showingOptions: $showingOptions)
            }
            
            // Selection overlay - removed to prevent duplicate checkmarks
            // Selection is now handled by SelectableNoteCard wrapper
        }
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        cardRect = geo.frame(in: .global)
                    }
                    .onChange(of: geo.frame(in: .global)) { _, newValue in
                        cardRect = newValue
                    }
            }
        )
        .onChange(of: showingOptions) { _, newValue in
            if newValue {
                openOptionsNoteId = note.id
                onContextMenuRequest?(note, cardRect)
            } else if openOptionsNoteId == note.id {
                openOptionsNoteId = nil
            }
        }
        .onChange(of: openOptionsNoteId) { _, newValue in
            if newValue != note.id {
                showingOptions = false
            }
        }
        .opacity(isSelectionMode && !isSelected ? 0.6 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelectionMode ? "Tap to select or deselect" : "Double tap to edit, long press for more options")
        .accessibilityAddTraits(isSelectionMode ? [.isButton] : [])
        .accessibilityValue(isSelectionMode && isSelected ? "Selected" : "")
    }
    
    private var accessibilityLabel: String {
        var label = note.type == .quote ? "Quote: " : "Note: "
        label += note.content
        
        if let bookTitle = note.bookTitle {
            label += ". From \(bookTitle)"
        }
        
        if let author = note.author {
            label += " by \(author)"
        }
        
        let formatter = RelativeDateTimeFormatter()
        label += ". Created \(formatter.localizedString(for: note.dateCreated, relativeTo: Date()))"
        
        return label
    }
    
    @EnvironmentObject var notesViewModel: NotesViewModel
}

// MARK: - Quote Card (Literary Design)
struct QuoteCard: View {
    let note: Note
    @Binding var isPressed: Bool
    @Binding var showingOptions: Bool
    @EnvironmentObject var notesViewModel: NotesViewModel
    @Environment(\.sizeCategory) var sizeCategory
    @State private var showDate = false
    
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
                .font(.custom("Georgia", size: sizeCategory.isAccessibilitySize ? 60 : 80))
                .foregroundStyle(Color.white.opacity(0.15))
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
                VStack(alignment: .leading, spacing: 6) {
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
                    }
                    
                    if let pageNumber = note.pageNumber {
                        Text("PAGE \(pageNumber)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .kerning(1.0)
                            .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                    }
                }
            }
            
            // Date overlay that fades in on swipe
            if showDate {
                HStack {
                    Spacer()
                    Text(note.formattedDate)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.5))
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .padding(32) // Generous padding
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.11, green: 0.105, blue: 0.102)) // Dark charcoal matching LibraryView
        )
        .shadow(color: Color(red: 0.8, green: 0.7, blue: 0.6).opacity(0.15), radius: 12, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: showDate)
        .onLongPressGesture(minimumDuration: 0.3) {
            // Show date on long press
            HapticManager.shared.lightTap()
            withAnimation(.easeInOut(duration: 0.3)) {
                showDate = true
            }
            // Hide date after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDate = false
                }
            }
        }
        .onTapGesture(count: 2) {
            HapticManager.shared.mediumTap()
            // Navigate to ambient session
            navigateToAmbientSession()
        }
    }
    
    private func navigateToAmbientSession() {
        // Find the ambient session this quote belongs to
        // For now, just open ambient mode - can be enhanced to find specific session
        SimplifiedAmbientCoordinator.shared.openAmbientReading()
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
                    .foregroundStyle(Color.white.opacity(0.2))
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
        .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture(count: 2) {
            HapticManager.shared.mediumTap()
            showingOptions = true
        }
    }
}