import SwiftUI

// MARK: - Enhanced Quick Actions Bar with Advanced Gestures
struct EnhancedQuickActionsBar: View {
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @EnvironmentObject var notesViewModel: NotesViewModel
    @ObservedObject private var voiceManager = VoiceRecognitionManager.shared
    
    // Gesture states
    @State private var showRadialMenu = false
    @State private var waveformGlow = false
    @State private var pulseAnimation = false
    @State private var lastTapTime: Date = .distantPast
    @State private var capturedContent: [String] = []
    @State private var showRecentCaptures = false
    @GestureState private var isLongPressing = false
    @GestureState private var dragOffset: CGSize = .zero
    
    // Visual feedback
    @State private var waveformScale: CGFloat = 1.0
    @State private var glowIntensity: Double = 0
    @Namespace private var animation
    
    private let warmAmber = Color(red: 1.0, green: 0.55, blue: 0.26)
    
    var body: some View {
        ZStack {
            // Main bar
            HStack(spacing: 0) {
                // Plus button for command palette
                plusButton
                
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.2))
                    .padding(.horizontal, 4)
                
                // Enhanced waveform button with gestures
                waveformButton
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
            
            // Radial book menu overlay
            if showRadialMenu {
                radialBookMenu
            }
            
            // Recent captures overlay
            if showRecentCaptures {
                recentCapturesView
            }
        }
        .onReceive(voiceManager.$currentAmplitude) { amplitude in
            if voiceManager.isListening {
                withAnimation(.easeInOut(duration: 0.3)) {
                    glowIntensity = Double(amplitude)
                }
            }
        }
        // Removed ambientManager observer as it no longer exists
    }
    
    // MARK: - Plus Button
    private var plusButton: some View {
        Button {
            HapticManager.shared.mediumTap()
            NotificationCenter.default.post(name: Notification.Name("ShowCommandInput"), object: nil)
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
    }
    
    // MARK: - Enhanced Waveform Button
    private var waveformButton: some View {
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
        }
        .scaleEffect(waveformScale)
        .onTapGesture {
            print("🎯 DEBUG: Waveform tap detected directly")
            handleTapGesture()
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
        print("🎯 DEBUG: Waveform single tap detected")
        HapticManager.shared.lightTap()
        startGlowAnimation()
        
        // Open simplified ambient mode
        print("🎯 DEBUG: About to call SimplifiedAmbientCoordinator.shared.openAmbientMode()")
        SimplifiedAmbientCoordinator.shared.openAmbientReading()
        print("🎯 DEBUG: Called SimplifiedAmbientCoordinator.shared.openAmbientMode()")
    }
    
    private func handleDoubleTap() {
        HapticManager.shared.success()
        
        // Double tap also opens simplified ambient mode
        SimplifiedAmbientCoordinator.shared.openAmbientReading()
    }
    
    private func handleSwipeGesture(_ translation: CGSize) {
        if translation.height < -30 {
            // Swipe up - Quick note capture
            HapticManager.shared.lightTap()
            NotificationCenter.default.post(name: Notification.Name("StartVoiceNote"), object: nil)
        } else if translation.height > 30 {
            // Swipe down - Show recent captures
            HapticManager.shared.lightTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
            .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
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
                .foregroundStyle(.white.opacity(0.7))
            
            if capturedContent.isEmpty {
                Text("No recent captures")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .italic()
            } else {
                ForEach(capturedContent.prefix(3), id: \.self) { content in
                    Text(content)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(12)
        .frame(width: 200)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12))
        .offset(y: -80)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.95, anchor: .bottom).combined(with: .opacity)
        ))
    }
    
    // MARK: - Helper Functions
    
    private func startGlowAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
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
        HapticManager.shared.success()
        dismissRadialMenu()
        
        // Open simplified ambient mode (book will be detected from speech)
        SimplifiedAmbientCoordinator.shared.openAmbientReading()
    }
    
    private func dismissRadialMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
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
        Color(red: 0.11, green: 0.105, blue: 0.102)
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