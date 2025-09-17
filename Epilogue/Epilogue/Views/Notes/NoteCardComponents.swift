import SwiftUI
import SwiftData

// Preference key for card rect tracking
private struct CardRectPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
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
    @State private var cardRect: CGRect = .zero
    var onContextMenuRequest: ((Note, CGRect) -> Void)?
    @Environment(\.sizeCategory) var sizeCategory
    @Environment(\.modelContext) private var modelContext
    @State private var ambientSession: AmbientSession?
    
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
                QuoteCard(note: note, isPressed: $isPressed, showingOptions: $showingOptions, ambientSession: ambientSession)
            } else {
                RegularNoteCard(note: note, isPressed: $isPressed, showingOptions: $showingOptions, ambientSession: ambientSession)
            }
            
            // Selection overlay - removed to prevent duplicate checkmarks
            // Selection is now handled by SelectableNoteCard wrapper
        }
        .overlay(
            GeometryReader { geo in
                Color.clear
                    .preference(key: CardRectPreferenceKey.self, value: geo.frame(in: .global))
                    .onAppear {
                        cardRect = geo.frame(in: .global)
                    }
            }
        )
        .onPreferenceChange(CardRectPreferenceKey.self) { newValue in
            // Only update if rect actually changed significantly
            if abs(cardRect.minY - newValue.minY) > 1 || abs(cardRect.minX - newValue.minX) > 1 {
                cardRect = newValue
            }
        }
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
        .animation(DesignSystem.Animation.springStandard, value: isSelected)
        .onAppear {
            loadAmbientSession()
        }
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
    private func loadAmbientSession() {
        guard let sessionId = note.ambientSessionId else { return }

        let fetchDescriptor = FetchDescriptor<AmbientSession>(
            predicate: #Predicate { session in
                session.id == sessionId
            }
        )

        if let sessions = try? modelContext.fetch(fetchDescriptor),
           let session = sessions.first {
            self.ambientSession = session
        }
    }

    @EnvironmentObject var notesViewModel: NotesViewModel
}

// MARK: - Quote Card (Literary Design)
struct QuoteCard: View {
    let note: Note
    @Binding var isPressed: Bool
    @Binding var showingOptions: Bool
    let ambientSession: AmbientSession?
    @EnvironmentObject var notesViewModel: NotesViewModel
    @Environment(\.sizeCategory) var sizeCategory
    @State private var showDate = false
    @State private var tapCount = 0
    @State private var lastTapTime = Date()
    @State private var showingSessionSummary = false
    
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

                // Session pill for ambient quotes
                if let session = ambientSession,
                   let source = note.source,
                   source == "ambient" {
                    Button {
                        showingSessionSummary = true
                        SensoryFeedback.light()
                    } label: {
                        HStack(spacing: 6) {
                            Text("SESSION")
                                .font(.system(size: 10, weight: .semibold, design: .default))
                                .kerning(1.0)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(DesignSystem.Colors.primaryAccent.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 8)
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
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                .fill(DesignSystem.Colors.surfaceBackground) // Dark charcoal matching LibraryView
        )
        .shadow(color: Color(red: 0.8, green: 0.7, blue: 0.6).opacity(0.15), radius: 12, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
        .animation(DesignSystem.Animation.easeStandard, value: showDate)
        .onTapGesture {
            handleTap()
        }
        .sheet(isPresented: $showingSessionSummary) {
            if let session = ambientSession {
                NavigationStack {
                    AmbientSessionSummaryView(session: session, colorPalette: nil)
                }
            }
        }
    }
    
    private func handleTap() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.3 {
            // Double tap detected
            SensoryFeedback.medium()
            navigateToAmbientSession()
            tapCount = 0
        } else {
            // Single tap - show date
            SensoryFeedback.light()
            withAnimation(DesignSystem.Animation.easeStandard) {
                showDate.toggle()
            }
            
            // Auto-hide after 3 seconds when showing
            if showDate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation(DesignSystem.Animation.easeStandard) {
                        showDate = false
                    }
                }
            }
        }
        
        lastTapTime = now
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
    let ambientSession: AmbientSession?
    @EnvironmentObject var notesViewModel: NotesViewModel
    @State private var showingSessionSummary = false
    
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

                        // Session pill for ambient notes
                        if let session = ambientSession,
                           let source = note.source,
                           source == "ambient" {
                            Button {
                                showingSessionSummary = true
                                SensoryFeedback.light()
                            } label: {
                                HStack(spacing: 6) {
                                    Text("SESSION")
                                        .font(.system(size: 10, weight: .semibold, design: .default))
                                        .kerning(1.0)

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 9, weight: .bold))
                                }
                                .foregroundColor(DesignSystem.Colors.primaryAccent.opacity(0.7))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                        .fill(DesignSystem.Colors.primaryAccent.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(DesignSystem.Spacing.listItemPadding)
        .glassEffect(.regular.tint(Color(red: 0.15, green: 0.145, blue: 0.14).opacity(0.6)), in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: isPressed)
        .onTapGesture(count: 2) {
            SensoryFeedback.medium()
            showingOptions = true
        }
        .sheet(isPresented: $showingSessionSummary) {
            if let session = ambientSession {
                NavigationStack {
                    AmbientSessionSummaryView(session: session, colorPalette: nil)
                }
            }
        }
    }
}