import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Display States
enum AmbientDisplayState {
    case listening
    case thinking
    case responding
    case complete
    
    var gradientIntensity: Double {
        switch self {
        case .listening:
            return 0.9
        case .thinking:
            return 0.7  // Dimmer while processing
        case .responding:
            return 1.0  // Brighter during response
        case .complete:
            return 0.85 // Settle to calm
        }
    }
    
    var description: String {
        switch self {
        case .listening:
            return "Listening..."
        case .thinking:
            return "Thinking..."
        case .responding:
            return "Speaking..."
        case .complete:
            return "Complete"
        }
    }
}

// MARK: - Main Ambient Mode View
struct AmbientModeView: View {
    // Core services
    @StateObject private var processor = SingleSourceProcessor.shared
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var libraryViewModel = LibraryViewModel()
    
    // Display state
    @State private var displayState: AmbientDisplayState = .listening
    @State private var isListening: Bool = true
    @State private var showSettings: Bool = false
    
    // Book and gradient
    @State private var currentBook: Book?
    @State private var bookPalette: ColorPalette?
    @State private var gradientIntensity: Double = 0.9
    
    // Voice parameters for gradient
    @State private var voiceFrequency: Double = 0.0
    @State private var voiceRhythm: Double = 0.0
    @State private var speakingSpeed: Double = 150.0 // Default WPM
    
    // UI state
    @State private var showBookSelector: Bool = false
    @State private var lastProcessedText: String = ""
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Default palette for when no book is selected
    private var ambientDefaultPalette: ColorPalette {
        ColorPalette(
            primary: Color(red: 1.0, green: 0.55, blue: 0.26),
            secondary: Color(red: 0.8, green: 0.3, blue: 0.4),
            accent: Color(red: 0.6, green: 0.2, blue: 0.5),
            background: Color.black,
            textColor: Color.white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 1.0
        )
    }
    
    var body: some View {
        ZStack {
            // MARK: - Enhanced Gradient Background (Your Signature)
            BookAtmosphericGradientView(
                colorPalette: bookPalette ?? ambientDefaultPalette,
                intensity: gradientIntensity + Double(voiceManager.audioLevel) * 0.3
            )
            .ignoresSafeArea()
            .animation(.smooth(duration: 0.3), value: gradientIntensity)
            .animation(.smooth(duration: 0.1), value: voiceManager.audioLevel)
            
            // MARK: - Vignette Overlay (Subtle Enhancement)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.1 + voiceManager.audioLevel * 0.05)
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.5), value: voiceManager.audioLevel)
            
            // MARK: - Edge Glow (Voice Responsive)
            if voiceManager.audioLevel > 0.3 {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(
                        LinearGradient(
                            colors: [
                                (bookPalette?.primary ?? ambientDefaultPalette.primary)
                                    .opacity(voiceManager.audioLevel * 0.3),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 3
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.2), value: voiceManager.audioLevel)
            }
            
            // MARK: - Minimal Control Overlay
            VStack {
                // Top controls
                HStack {
                    // Exit button
                    Button(action: exitAmbientMode) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .glassEffect(in: .circle)
                    }
                    
                    Spacer()
                    
                    // Book selector
                    Button(action: { showBookSelector.toggle() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 16, weight: .medium))
                            if let book = currentBook {
                                Text(book.title)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                            } else {
                                Text("Select Book")
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(in: .capsule)
                    }
                    
                    Spacer()
                    
                    // Settings button
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                            .glassEffect(in: .circle)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
                
                // MARK: - Center Status Display (Minimal)
                if displayState != .listening {
                    Text(displayState.description)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .glassEffect(in: .capsule)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Spacer()
                
                // MARK: - Bottom Controls
                HStack(spacing: 40) {
                    // History button (optional)
                    Button(action: showHistory) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .glassEffect(in: .circle)
                    }
                    
                    // Main Pause/Resume button
                    Button(action: toggleListening) {
                        ZStack {
                            // Animated ring when listening
                            if isListening {
                                Circle()
                                    .stroke(.white.opacity(0.2), lineWidth: 2)
                                    .frame(width: 72, height: 72)
                                    .scaleEffect(isListening ? 1.1 : 1.0)
                                    .opacity(isListening ? 0.8 : 0.0)
                                    .animation(
                                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                        value: isListening
                                    )
                            }
                            
                            Image(systemName: isListening ? "pause.fill" : "mic.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.white)
                                .symbolEffect(.variableColor.iterative, options: .repeating, value: isListening)
                                .frame(width: 64, height: 64)
                                .glassEffect(in: .circle)
                        }
                    }
                    .scaleEffect(isListening ? 1.0 : 0.95)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isListening)
                    
                    // Keyboard input button (optional)
                    Button(action: showKeyboard) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .glassEffect(in: .circle)
                    }
                }
                .padding(.bottom, 50)
            }
            
            // MARK: - Book Selector Sheet
            .sheet(isPresented: $showBookSelector) {
                BookSelectorSheet(
                    selectedBook: $currentBook,
                    onSelect: { book in
                        selectBook(book)
                        showBookSelector = false
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            
            // MARK: - Settings Sheet
            .sheet(isPresented: $showSettings) {
                AmbientSettingsView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onChange(of: displayState) { _, newState in
            updateGradientForState(newState)
        }
        .onChange(of: voiceManager.audioLevel) { _, newLevel in
            updateVoiceParameters()
        }
        .onAppear {
            startAmbientMode()
        }
        .onDisappear {
            stopAmbientMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .processingStarted)) { _ in
            withAnimation(.easeIn(duration: 0.3)) {
                displayState = .thinking
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .processingComplete)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                displayState = .listening
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiResponseStarted)) { _ in
            withAnimation(.easeIn(duration: 0.3)) {
                displayState = .responding
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .aiResponseComplete)) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                displayState = .listening
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func startAmbientMode() {
        isListening = true
        voiceManager.startAmbientListening()
        
        // Extract colors if we have a book
        if let book = currentBook {
            Task {
                await extractColorsForBook(book)
            }
        }
    }
    
    private func stopAmbientMode() {
        isListening = false
        voiceManager.stopListening()
        // processor.clearBuffer() // TODO: Add this method if needed
    }
    
    private func exitAmbientMode() {
        HapticManager.shared.lightTap()
        stopAmbientMode()
        dismiss()
    }
    
    private func toggleListening() {
        HapticManager.shared.lightTap()
        isListening.toggle()
        
        if isListening {
            voiceManager.startAmbientListening()
            withAnimation(.spring(response: 0.3)) {
                displayState = .listening
            }
        } else {
            voiceManager.stopListening()
            withAnimation(.spring(response: 0.3)) {
                displayState = .complete
            }
        }
    }
    
    private func selectBook(_ book: Book) {
        currentBook = book
        HapticManager.shared.lightTap()
        
        Task {
            await extractColorsForBook(book)
        }
    }
    
    private func extractColorsForBook(_ book: Book) async {
        guard let coverURLString = book.coverImageURL,
              let coverURL = URL(string: coverURLString) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: coverURL)
            if let image = UIImage(data: data) {
                let extractor = OKLABColorExtractor()
                let palette = try await extractor.extractPalette(from: image)
                
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        self.bookPalette = palette
                    }
                }
            }
        } catch {
            print("Failed to extract colors: \(error)")
        }
    }
    
    private func updateGradientForState(_ state: AmbientDisplayState) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            gradientIntensity = state.gradientIntensity
        }
    }
    
    private func updateVoiceParameters() {
        // Update voice-responsive parameters
        // These would come from enhanced VoiceRecognitionManager
        voiceFrequency = voiceManager.voiceFrequency
        voiceRhythm = voiceManager.voiceRhythm
        speakingSpeed = voiceManager.wordsPerMinute
    }
    
    private func mapFrequency(_ frequency: Double) -> Double {
        // Map voice frequency (0-1000 Hz) to 0-1 range for gradient
        return min(1.0, max(0.0, frequency / 1000.0))
    }
    
    private func showHistory() {
        // Show session history
        HapticManager.shared.lightTap()
    }
    
    private func showKeyboard() {
        // Show keyboard input
        HapticManager.shared.lightTap()
    }
}

// MARK: - Book Selector Sheet
struct BookSelectorSheet: View {
    @Binding var selectedBook: Book?
    let onSelect: (Book) -> Void
    @StateObject private var libraryViewModel = LibraryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100), spacing: 16)
                ], spacing: 16) {
                    ForEach(libraryViewModel.books) { book in
                        Button(action: { onSelect(book) }) {
                            VStack(spacing: 8) {
                                SharedBookCoverView(
                                    coverURL: book.coverImageURL,
                                    width: 80,
                                    height: 120
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    if selectedBook?.id == book.id {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 3)
                                    }
                                }
                                
                                Text(book.title)
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings View
struct AmbientSettingsView: View {
    @AppStorage("ambientAutoSave") private var autoSave = true
    @AppStorage("ambientVoiceSpeed") private var voiceSpeed = 1.0
    @AppStorage("ambientSensitivity") private var sensitivity = 0.5
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Processing") {
                    Toggle("Auto-save quotes & notes", isOn: $autoSave)
                    
                    HStack {
                        Text("Voice Sensitivity")
                        Slider(value: $sensitivity, in: 0...1)
                            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                }
                
                Section("Voice") {
                    HStack {
                        Text("Speaking Speed")
                        Slider(value: $voiceSpeed, in: 0.5...2.0)
                            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                }
            }
            .navigationTitle("Ambient Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let processingStarted = Notification.Name("AmbientProcessingStarted")
    static let processingComplete = Notification.Name("AmbientProcessingComplete")
    static let aiResponseStarted = Notification.Name("AmbientAIResponseStarted")
    static let aiResponseComplete = Notification.Name("AmbientAIResponseComplete")
}

// MARK: - Preview
#Preview {
    AmbientModeView()
        .modelContainer(for: [CapturedNote.self, CapturedQuote.self])
}