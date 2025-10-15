import SwiftUI

// MARK: - Enhanced Quick Actions Bar with Advanced Gestures
struct EnhancedQuickActionsBar: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @ObservedObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var microInteractionManager = MicroInteractionManager.shared

    // Gesture states
    @State private var showRadialMenu = false
    @State private var waveformGlow = false
    @State private var pulseAnimation = false
    @State private var lastTapTime: Date = .distantPast
    @State private var capturedContent: [String] = []
    @State private var showRecentCaptures = false
    @State private var showCommandPalette = false
    @GestureState private var isLongPressing = false
    @GestureState private var dragOffset: CGSize = .zero
    
    // Visual feedback
    @State private var waveformScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0
    @Namespace private var animation
    
    private let warmAmber = DesignSystem.Colors.primaryAccent
    
    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                // Main bar only (orb moved to tab navigation)
                HStack(spacing: 0) {
                    // Plus button for command palette
                    plusButton

                    Divider()
                        .frame(height: 20)
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 8)

                    // Ambient Metal shader button (no orb container)
                    ambientShaderButton
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassEffect(in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }

            // Radial book menu overlay
            if showRadialMenu {
                radialBookMenu
            }

            // Recent captures overlay
            if showRecentCaptures {
                recentCapturesView
            }
        }
        .fullScreenCover(isPresented: $showCommandPalette) {
            LiquidCommandPaletteV2(
                isPresented: $showCommandPalette,
                context: libraryViewModel.currentDetailBook != nil ?
                    .bookDetail(libraryViewModel.currentDetailBook!) : .library
            ) { result in
                handleCommandResult(result)
            }
            .environmentObject(libraryViewModel)
            .environmentObject(notesViewModel)
            .presentationBackground(Color.clear)
        }
        .onReceive(voiceManager.$currentAmplitude) { amplitude in
            if voiceManager.isListening {
                withAnimation(DesignSystem.Animation.easeStandard) {
                    glowIntensity = Double(amplitude)
                }
            }
        }
    }
    
    // MARK: - Plus Button
    private var plusButton: some View {
        Button {
            SensoryFeedback.medium()
            // Show the liquid command palette
            showCommandPalette = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
    }
    
    // MARK: - Ambient Shader Button (Metal shader, no orb)
    private var ambientShaderButton: some View {
        Button {
            SensoryFeedback.light()
            // Open ambient mode
            if let currentBook = libraryViewModel.currentDetailBook {
                SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
            } else {
                SimplifiedAmbientCoordinator.shared.openAmbientReading()
            }
        } label: {
            // Just the Metal shader, no container
            AmbientOrbButton(size: 36) {
                // Action handled by parent button
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Voice Input Button (waveform for voice commands)
    private var voiceInputButton: some View {
        ZStack {
            // Glow effect when active
            if waveformGlow {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                warmAmber.opacity(0.3 + glowIntensity * 0.3),
                                warmAmber.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 25
                        )
                    )
                    .frame(width: 50, height: 50)
                    .blur(radius: 8)
                    .scaleEffect(pulseAnimation ? 1.3 : 1.0)
            }
            
            // Waveform icon with animation
            Image(systemName: voiceManager.isListening ? "waveform.path.ecg" : "waveform")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(waveformGlow ? warmAmber : .white)
                .symbolEffect(
                    .bounce,
                    options: voiceManager.isListening ? .repeating : .default,
                    value: voiceManager.isListening
                )
                .scaleEffect(waveformScale)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .modifier(BlurToAmberAnimation(
                    isActive: microInteractionManager.showAmbientIconAnimation &&
                             libraryViewModel.currentDetailBook != nil  // Only animate in BookDetailView
                ))
        }
        .scaleEffect(waveformScale)
        .onTapGesture {
            #if DEBUG
            print("🎤 DEBUG: Voice button tap detected")
            #endif
            handleVoiceInput()
        }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.7), trigger: waveformGlow)
    }
    
    // MARK: - Gesture Handlers
    
    private func handleTapGesture() {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(lastTapTime)
        
        if timeSinceLastTap < 0.5 {
            // Double tap detected
            handleDoubleTap()
        } else {
            // Single tap
            handleSingleTap()
        }
        
        lastTapTime = now
    }
    
    private func handleSingleTap() {
        #if DEBUG
        print("🎯 DEBUG: Ambient orb tap detected")
        #endif
        SensoryFeedback.light()
        startGlowAnimation()

        // Check if we're viewing a specific book
        if let currentBook = libraryViewModel.currentDetailBook {
            #if DEBUG
            print("📚 Opening ambient mode with book: \(currentBook.title)")
            #endif
            SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
        } else {
            #if DEBUG
            print("🎯 DEBUG: Opening generic ambient mode")
            #endif
            SimplifiedAmbientCoordinator.shared.openAmbientReading()
        }
    }

    private func handleVoiceInput() {
        #if DEBUG
        print("🎤 Starting voice input for commands")
        #endif
        SensoryFeedback.light()
        startGlowAnimation()

        // Start voice recognition for commands
        NotificationCenter.default.post(name: Notification.Name("StartVoiceCommand"), object: nil)
    }
    
    private func handleDoubleTap() {
        SensoryFeedback.success()
        
        // Double tap also checks for current book context
        if let currentBook = libraryViewModel.currentDetailBook {
            SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
        } else {
            SimplifiedAmbientCoordinator.shared.openAmbientReading()
        }
    }
    
    private func handleSwipeGesture(_ translation: CGSize) {
        if translation.height < -30 {
            // Swipe up - Quick note capture
            SensoryFeedback.light()
            NotificationCenter.default.post(name: Notification.Name("StartVoiceNote"), object: nil)
        } else if translation.height > 30 {
            // Swipe down - Show recent captures
            SensoryFeedback.light()
            withAnimation(DesignSystem.Animation.springStandard) {
                showRecentCaptures = true
            }
            
            // Auto-hide after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showRecentCaptures = false
                }
            }
        }
    }
    
    // MARK: - Radial Book Menu
    
    private var radialBookMenu: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissRadialMenu()
                }
            
            // Radial menu items
            ForEach(Array(libraryViewModel.books.prefix(5).enumerated()), id: \.element.id) { index, book in
                radialMenuItem(book: book, index: index, total: min(5, libraryViewModel.books.count))
            }
            
            // Center dismiss button
            Button {
                dismissRadialMenu()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: Circle())
            }
            .transition(.scale.combined(with: .opacity))
        }
        .drawingGroup() // Performance optimization
    }
    
    private func radialMenuItem(book: Book, index: Int, total: Int) -> some View {
        let angle = Double(index) * (360.0 / Double(total)) - 90
        let radius: CGFloat = 100
        let x = radius * cos(angle * .pi / 180)
        let y = radius * sin(angle * .pi / 180)
        
        return Button {
            selectBook(book)
        } label: {
            VStack(spacing: 4) {
                SharedBookCoverView(
                    coverURL: book.coverImageURL,
                    width: 40,
                    height: 60
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: warmAmber.opacity(0.3), radius: 4)
                
                Text(book.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 60)
            }
            .padding(8)
            .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .strokeBorder(warmAmber.opacity(0.3), lineWidth: 1)
            }
        }
        .offset(x: x, y: y)
        .scaleEffect(showRadialMenu ? 1 : 0.5)
        .opacity(showRadialMenu ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.7)
            .delay(Double(index) * 0.05),
            value: showRadialMenu
        )
    }
    
    // MARK: - Recent Captures View
    
    private var recentCapturesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Captures")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
            
            if capturedContent.isEmpty {
                Text("No recent captures")
                    .font(.system(size: 11))
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .italic()
            } else {
                ForEach(capturedContent.prefix(3), id: \.self) { content in
                    Text(content)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.small))
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .glassEffect(in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
        .offset(y: -80)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity)
        ))
    }
    
    // MARK: - Helper Functions

    private func handleCommandResult(_ result: LiquidCommandPaletteV2.CommandResult) {
        switch result {
        case .note(let text):
            // Create a new note with book context if available
            var noteData: [String: Any] = ["content": text]
            if let currentBook = libraryViewModel.currentDetailBook {
                noteData["bookId"] = currentBook.id
                noteData["bookTitle"] = currentBook.title
                noteData["bookAuthor"] = currentBook.author
            }
            NotificationCenter.default.post(
                name: Notification.Name("CreateNewNote"),
                object: noteData
            )
        case .quote(let text, let attribution):
            // Save a quote with book context if available
            var quoteData: [String: Any] = ["quote": text, "attribution": attribution ?? ""]
            if let currentBook = libraryViewModel.currentDetailBook {
                quoteData["bookId"] = currentBook.id
                quoteData["bookTitle"] = currentBook.title
                quoteData["bookAuthor"] = currentBook.author
            }
            NotificationCenter.default.post(
                name: Notification.Name("SaveQuote"),
                object: quoteData
            )
        case .bookAdded(let book):
            // Book was added
            libraryViewModel.addBook(book)
        case .search(let query):
            // Perform search
            NotificationCenter.default.post(
                name: Notification.Name("PerformSearch"),
                object: ["query": query]
            )
        case .cancel:
            // Cancelled, do nothing
            break
        }
    }

    private func startGlowAnimation() {
        withAnimation(DesignSystem.Animation.easeStandard) {
            waveformGlow = true
            pulseAnimation = true
            waveformScale = 1.1
        }
        
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation.toggle()
        }
        
        // Stop after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                waveformGlow = false
                pulseAnimation = false
                waveformScale = 1.0
            }
        }
    }
    
    private func selectBook(_ book: Book) {
        SensoryFeedback.success()
        dismissRadialMenu()
        
        // Open ambient mode with the selected book
        SimplifiedAmbientCoordinator.shared.openAmbientReading(with: book)
    }
    
    private func dismissRadialMenu() {
        withAnimation(DesignSystem.Animation.springStandard) {
            showRadialMenu = false
            waveformScale = 1.0
        }
    }
}

// MARK: - Gesture Modifiers

struct WaveformGestureModifier: ViewModifier {
    let onSingleTap: () -> Void
    let onDoubleTap: () -> Void
    let onLongPress: () -> Void
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void
    
    @State private var lastTapTime: Date = .distantPast
    @GestureState private var dragOffset: CGSize = .zero
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        if value.translation.height < -30 {
                            onSwipeUp()
                        } else if value.translation.height > 30 {
                            onSwipeDown()
                        }
                    }
            )
            .onTapGesture {
                let now = Date()
                if now.timeIntervalSince(lastTapTime) < 0.5 {
                    onDoubleTap()
                } else {
                    onSingleTap()
                }
                lastTapTime = now
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                onLongPress()
            }
    }
}

// MARK: - Performance Optimizations

extension View {
    func optimizedForHighFrameRate() -> some View {
        self
            .drawingGroup()
            .compositingGroup()
    }
}

// MARK: - Accessibility

extension EnhancedQuickActionsBar {
    func addAccessibilityActions() -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quick Actions")
            .accessibilityHint("Tap for voice mode, double tap for last book, long press for book menu")
            .accessibilityAction(named: "Open Voice Mode") {
                handleSingleTap()
            }
            .accessibilityAction(named: "Open with Last Book") {
                handleDoubleTap()
            }
            .accessibilityAction(named: "Show Book Menu") {
                withAnimation {
                    showRadialMenu = true
                }
            }
            .accessibilityAction(named: "Quick Note") {
                NotificationCenter.default.post(name: Notification.Name("StartVoiceNote"), object: nil)
            }
    }
}

#Preview {
    ZStack {
        DesignSystem.Colors.surfaceBackground
            .ignoresSafeArea()

        VStack {
            Spacer()
            EnhancedQuickActionsBar()
                .environmentObject(LibraryViewModel())
                .environmentObject(NotesViewModel())
                .padding(.bottom, 100)
        }
    }
}