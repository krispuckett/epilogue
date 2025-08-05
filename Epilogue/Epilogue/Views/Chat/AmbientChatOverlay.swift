import SwiftUI
import SwiftData
import UIImageColors

// MARK: - Ambient Session Model
struct AmbientSession: Identifiable {
    let id = UUID()
    let startTime: Date
    var endTime: Date?
    var book: Book?
    var rawTranscriptions: [String] = []
    var processedData: ProcessedAmbientSession?
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
}

struct ProcessedAmbientSession {
    let quotes: [ExtractedQuote]
    let notes: [ExtractedNote]
    let questions: [ExtractedQuestion]
    let summary: String
    let duration: TimeInterval
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

// ExtractedQuote, ExtractedNote, and ExtractedQuestion are now in AmbientSessionModels.swift

// MARK: - Claude-Inspired Gradient Background
struct ClaudeInspiredGradient: View {
    @State private var phase: CGFloat = 0
    let book: Book?
    let colorPalette: ColorPalette? // Changed from @State to regular property
    @Binding var audioLevel: Float
    @Binding var isListening: Bool
    
    // Voice pattern parameters
    let voiceFrequency: CGFloat
    let voiceIntensity: CGFloat
    let voiceRhythm: CGFloat
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if let palette = colorPalette, book != nil {
                // Book-specific gradient when we have colors
                BookSpecificGradient(
                    palette: palette,
                    phase: phase,
                    audioLevel: audioLevel,
                    isListening: isListening,
                    voiceFrequency: voiceFrequency,
                    voiceIntensity: voiceIntensity,
                    voiceRhythm: voiceRhythm
                )
                .onAppear {
                    print("🎨 BookSpecificGradient appeared with voiceIntensity: \(voiceIntensity)")
                }
                .onChange(of: voiceIntensity) { _, newIntensity in
                    if newIntensity > 0.01 {
                        print("🎨 Gradient voiceIntensity changed to: \(newIntensity)")
                    }
                }
            } else {
                // Default enhanced amber gradient with motion
                EnhancedAmberGradient(
                    phase: phase,
                    audioLevel: audioLevel,
                    isListening: isListening,
                    voiceFrequency: voiceFrequency,
                    voiceIntensity: voiceIntensity,
                    voiceRhythm: voiceRhythm
                )
            }
        }
        .onAppear {
            startWaveAnimation()
        }
    }
    
    private func startWaveAnimation() {
        phase = 1
    }
}

// Enhanced amber gradient - mirrored version without jumps
struct EnhancedAmberGradient: View {
    let phase: CGFloat
    let audioLevel: Float
    let isListening: Bool
    let voiceFrequency: CGFloat
    let voiceIntensity: CGFloat
    let voiceRhythm: CGFloat
    
    // Refined voice-modulated color function
    private func voiceModulatedColor(base: Color, level: CGFloat) -> Color {
        let uiColor = UIColor(base)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Subtle color shifts based on voice level
        let hueShift = sin(level * .pi) * 0.05 // ±5% hue variation
        let newHue = (hue + hueShift).truncatingRemainder(dividingBy: 1.0)
        
        // Saturation and brightness respond to voice
        let newSaturation = min(saturation + (level * 0.2), 1.0) // Up to 20% more saturated
        let newBrightness = min(brightness + (level * 0.15), 1.0) // Up to 15% brighter
        
        return Color(hue: newHue, saturation: newSaturation, brightness: newBrightness, opacity: alpha)
    }
    
    // EXTREME color modulation based on voice characteristics
    private func modulatedColor(base: Color, frequency: CGFloat, intensity: CGFloat) -> Color {
        let uiColor = UIColor(base)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // EXTREME hue shift based on frequency (warmer for low, cooler for high)
        let hueShift = (frequency - 0.5) * 0.2 // ±20% hue shift (doubled!)
        let newHue = (hue + hueShift).truncatingRemainder(dividingBy: 1.0)
        
        // EXTREME saturation boost with intensity
        let newSaturation = min(saturation + (intensity * 0.6), 1.0) // Doubled!
        
        // EXTREME brightness responds to overall energy
        let newBrightness = min(brightness + (intensity * 0.5), 1.0) // More than doubled!
        
        // Over-saturate opacity when loud
        let newAlpha = min(alpha * (1.0 + (intensity * 0.5)), 1.0)
        
        return Color(hue: newHue, saturation: newSaturation, brightness: newBrightness, opacity: newAlpha)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base black layer
                Color.black
                
                // Top gradient container
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 1.0, green: 0.35, blue: 0.1), location: 0.0),
                            .init(color: Color(red: 1.0, green: 0.55, blue: 0.26), location: 0.15),
                            .init(color: Color(red: 1.0, green: 0.7, blue: 0.4).opacity(0.5), location: 0.3),
                            .init(color: Color.clear, location: 0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.6)
                    .blur(radius: 40)
                    .scaleEffect(y: 0.8 + phase * 0.15)
                    .opacity(0.8 + phase * 0.1)
                    
                    Spacer()
                }
                
                // Voice-responsive bottom gradient - REFINED VERSION
                ZStack {
                    // Base gradient layer (always visible)
                    VStack(spacing: 0) {
                        Spacer()
                        
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 1.0, green: 0.55, blue: 0.26), location: 0.0),
                                .init(color: Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.5), location: 0.3),
                                .init(color: Color.clear, location: 0.6)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: geometry.size.height * 0.5)
                        .blur(radius: 40)
                    }
                    
                    // Voice-responsive overlay (capped at 50% height)
                    VStack(spacing: 0) {
                        Spacer()
                        
                        LinearGradient(
                            stops: [
                                .init(
                                    color: voiceModulatedColor(base: Color(red: 1.0, green: 0.55, blue: 0.26), level: voiceIntensity),
                                    location: 0.0
                                ),
                                .init(
                                    color: voiceModulatedColor(base: Color(red: 1.0, green: 0.55, blue: 0.26), level: voiceIntensity).opacity(0.6),
                                    location: 0.2 + (voiceIntensity * 0.1)
                                ),
                                .init(
                                    color: voiceModulatedColor(base: Color(red: 1.0, green: 0.55, blue: 0.26), level: voiceIntensity).opacity(0.3),
                                    location: 0.4 + (voiceIntensity * 0.2)
                                ),
                                .init(
                                    color: Color.clear,
                                    location: 0.6 + (voiceIntensity * 0.2)
                                )
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: geometry.size.height * 0.5)
                        .blur(radius: 40 + (voiceIntensity * 20)) // Subtle blur increase
                        .scaleEffect(
                            x: 1.0,
                            y: 1.0 + (voiceIntensity * 0.3), // Max 30% height increase
                            anchor: .bottom
                        )
                        .opacity(0.5 + (voiceIntensity * 0.5)) // Fade in with voice
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: voiceIntensity)
                    }
                    
                    // Gentle pulsing glow at the base
                    VStack {
                        Spacer()
                        
                        Circle()
                            .fill(voiceModulatedColor(base: Color(red: 1.0, green: 0.55, blue: 0.26), level: voiceIntensity))
                            .blur(radius: 80)
                            .frame(width: 300, height: 300)
                            .scaleEffect(1.0 + (voiceIntensity * 0.3))
                            .opacity(voiceIntensity * 0.3)
                            .offset(y: 150) // Keep it anchored at bottom
                            .animation(.easeInOut(duration: 0.4), value: voiceIntensity)
                    }
                }
                // IMPORTANT: Clip to bottom 50% of screen
                .mask(
                    LinearGradient(
                        colors: [Color.black, Color.black, Color.clear],
                        startPoint: .bottom,
                        endPoint: UnitPoint(x: 0.5, y: 0.5) // Cuts off at 50% height
                    )
                )
            }
        }
        .ignoresSafeArea()
    }
}

// Book-specific gradient using the rebuilt system
struct BookSpecificGradient: View {
    let palette: ColorPalette
    let phase: CGFloat
    let audioLevel: Float
    let isListening: Bool
    let voiceFrequency: CGFloat
    let voiceIntensity: CGFloat
    let voiceRhythm: CGFloat
    
    // Refined voice-modulated color function
    private func voiceModulatedColor(base: Color, level: CGFloat) -> Color {
        let uiColor = UIColor(base)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Subtle color shifts based on voice level
        let hueShift = sin(level * .pi) * 0.05 // ±5% hue variation
        let newHue = (hue + hueShift).truncatingRemainder(dividingBy: 1.0)
        
        // Saturation and brightness respond to voice
        let newSaturation = min(saturation + (level * 0.2), 1.0) // Up to 20% more saturated
        let newBrightness = min(brightness + (level * 0.15), 1.0) // Up to 15% brighter
        
        return Color(hue: newHue, saturation: newSaturation, brightness: newBrightness, opacity: alpha)
    }
    
    // EXTREME color modulation based on voice characteristics
    private func modulatedColor(base: Color, frequency: CGFloat, intensity: CGFloat) -> Color {
        let uiColor = UIColor(base)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // EXTREME hue shift based on frequency (warmer for low, cooler for high)
        let hueShift = (frequency - 0.5) * 0.2 // ±20% hue shift (doubled!)
        let newHue = (hue + hueShift).truncatingRemainder(dividingBy: 1.0)
        
        // EXTREME saturation boost with intensity
        let newSaturation = min(saturation + (intensity * 0.6), 1.0) // Doubled!
        
        // EXTREME brightness responds to overall energy
        let newBrightness = min(brightness + (intensity * 0.5), 1.0) // More than doubled!
        
        // Over-saturate opacity when loud
        let newAlpha = min(alpha * (1.0 + (intensity * 0.5)), 1.0)
        
        return Color(hue: newHue, saturation: newSaturation, brightness: newBrightness, opacity: newAlpha)
    }
    
    private var enhancedPrimary: Color {
        enhanceColor(palette.primary)
    }
    
    private var enhancedSecondary: Color {
        enhanceColor(palette.secondary)
    }
    
    private var enhancedAccent: Color {
        enhanceColor(palette.accent)
    }
    
    private func enhanceColor(_ color: Color) -> Color {
        // Same enhancement as BookCoverBackgroundView
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Boost saturation and brightness
        let enhancedSaturation = min(1.0, saturation * 1.5)
        let enhancedBrightness = min(1.0, brightness * 1.3)
        
        return Color(hue: hue, saturation: enhancedSaturation, brightness: enhancedBrightness, opacity: alpha)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base black layer
                Color.black
                
                // Top gradient container with book colors
                VStack(spacing: 0) {
                    LinearGradient(
                        stops: [
                            .init(color: enhancedPrimary, location: 0.0),
                            .init(color: enhancedPrimary.opacity(0.9), location: 0.1),
                            .init(color: enhancedSecondary.opacity(0.7), location: 0.25),
                            .init(color: enhancedAccent.opacity(0.5), location: 0.4),
                            .init(color: Color.clear, location: 0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.65)
                    .blur(radius: 45)
                    .scaleEffect(y: 0.8 + phase * 0.12)
                    .opacity(0.7 + phase * 0.15)
                    
                    Spacer()
                }
                
                // Voice-responsive bottom gradient - REFINED VERSION
                ZStack {
                    // Base gradient layer (always visible)
                    VStack(spacing: 0) {
                        Spacer()
                        
                        LinearGradient(
                            stops: [
                                .init(color: enhancedAccent, location: 0.0),
                                .init(color: enhancedAccent.opacity(0.5), location: 0.3),
                                .init(color: Color.clear, location: 0.6)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: geometry.size.height * 0.5)
                        .blur(radius: 40)
                    }
                    
                    // Voice-responsive overlay (capped at 50% height)
                    VStack(spacing: 0) {
                        Spacer()
                        
                        LinearGradient(
                            stops: [
                                .init(
                                    color: voiceModulatedColor(base: enhancedAccent, level: voiceIntensity),
                                    location: 0.0
                                ),
                                .init(
                                    color: voiceModulatedColor(base: enhancedAccent, level: voiceIntensity).opacity(0.6),
                                    location: 0.2 + (voiceIntensity * 0.1)
                                ),
                                .init(
                                    color: voiceModulatedColor(base: enhancedSecondary, level: voiceIntensity).opacity(0.3),
                                    location: 0.4 + (voiceIntensity * 0.2)
                                ),
                                .init(
                                    color: Color.clear,
                                    location: 0.6 + (voiceIntensity * 0.2)
                                )
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                        .frame(height: geometry.size.height * 0.5)
                        .blur(radius: 40 + (voiceIntensity * 20)) // Subtle blur increase
                        .scaleEffect(
                            x: 1.0,
                            y: 1.0 + (voiceIntensity * 0.3), // Max 30% height increase
                            anchor: .bottom
                        )
                        .opacity(0.5 + (voiceIntensity * 0.5)) // Fade in with voice
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: voiceIntensity)
                    }
                    
                    // Gentle pulsing glow at the base
                    VStack {
                        Spacer()
                        
                        Circle()
                            .fill(voiceModulatedColor(base: enhancedAccent, level: voiceIntensity))
                            .blur(radius: 80)
                            .frame(width: 300, height: 300)
                            .scaleEffect(1.0 + (voiceIntensity * 0.3))
                            .opacity(voiceIntensity * 0.3)
                            .offset(y: 150) // Keep it anchored at bottom
                            .animation(.easeInOut(duration: 0.4), value: voiceIntensity)
                    }
                }
                // IMPORTANT: Clip to bottom 50% of screen
                .mask(
                    LinearGradient(
                        colors: [Color.black, Color.black, Color.clear],
                        startPoint: .bottom,
                        endPoint: UnitPoint(x: 0.5, y: 0.5) // Cuts off at 50% height
                    )
                )
            }
        }
        .ignoresSafeArea()
    }
}


// MARK: - Minimal Book Selection
struct MinimalBookSelection: View {
    @Binding var selectedBook: Book?
    @State private var showingBookPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("What are you reading?")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Say the book title or tap to select")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
            
            Button {
                showingBookPicker = true
            } label: {
                Image(systemName: "book")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet(onBookSelected: { book in
                selectedBook = book
                showingBookPicker = false
            })
        }
    }
}

// MARK: - Minimal Ambient Chat Overlay
struct AmbientChatOverlay: View {
    @Binding var isActive: Bool
    @Binding var selectedBook: Book?
    @Binding var session: AmbientSession?
    
    @State private var pulseAnimation = false
    @StateObject private var voiceManager = VoiceRecognitionManager.shared
    @StateObject private var pipeline = AmbientIntelligencePipeline()
    @State private var audioLevel: Float = 0
    @State private var isRecording = false
    @State private var showProcessingView = false
    @State private var showingSummary = false
    @State private var processedSession: ProcessedAmbientSession?
    @State private var showingBookPicker = false
    @Environment(\.modelContext) private var modelContext
    @State private var detectedPatterns: [PatternMatch] = []
    @State private var showPatternVisualizer = false
    @StateObject private var autoStopManager = AutoStopManager.shared
    @State private var showAutoStopWarning = false
    @State private var realtimeQuestions: [String] = []  // Track questions already processed in real-time
    @State private var bookColorPalette: ColorPalette? = nil  // Store extracted colors
    
    var body: some View {
        ZStack {
            // Claude-inspired gradient background
            ClaudeInspiredGradient(
                book: selectedBook,
                colorPalette: bookColorPalette,
                audioLevel: $audioLevel,
                isListening: $isRecording,
                voiceFrequency: voiceManager.voiceFrequency,
                voiceIntensity: voiceManager.voiceIntensity,
                voiceRhythm: voiceManager.voiceRhythm
            )
            .ignoresSafeArea()
            
            VStack {
                // Minimal header with close button only
                HStack {
                    Spacer()
                    
                    Button {
                        // Simple direct close without processing
                        voiceManager.stopListening()
                        autoStopManager.stopMonitoring()
                        isActive = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Central content
                if selectedBook == nil {
                    // Book selection
                    MinimalBookSelection(selectedBook: $selectedBook)
                } else if let book = selectedBook {
                    // Show book cover instead of listening indicator
                    VStack(spacing: 16) {
                        if let coverURL = book.coverImageURL {
                            SharedBookCoverView(coverURL: coverURL, width: 80, height: 112)
                                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                        } else {
                            // Fallback if no cover
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 80, height: 112)
                                .overlay(
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                        }
                        
                        // Small listening indicator below book
                        if voiceManager.isListening {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .symbolEffect(.variableColor.iterative, options: .repeating)
                                
                                // Show pattern indicator if detected
                                if let latestPattern = detectedPatterns.last {
                                    Text(latestPattern.pattern.rawValue)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color(hexString: latestPattern.pattern.color))
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Stop button with text above
                if selectedBook != nil {
                    VStack(spacing: 20) {
                        // Status text moved here
                        VStack(spacing: 8) {
                            Text(statusText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            
                            // Book title with swap button
                            if let book = selectedBook {
                                HStack(spacing: 8) {
                                    Text(book.title)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    
                                    Button {
                                        // Stop listening and show book picker
                                        voiceManager.stopListening()
                                        showingBookPicker = true
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                            .frame(width: 28, height: 28)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 40)
                            }
                        }
                        
                        Button {
                            stopSession()
                        } label: {
                            Text("Stop Listening")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 50)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(25)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            
            // Processing overlay
            if showProcessingView {
                ProcessingOverlay(session: session)
                    .transition(.opacity)
            }
            
            // Pattern visualizer overlay
            if showPatternVisualizer && !detectedPatterns.isEmpty {
                CognitivePatternVisualizer(patterns: detectedPatterns)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Auto-stop warning
            if showAutoStopWarning {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                AutoStopWarningView(
                    timeRemaining: autoStopManager.timeRemaining,
                    onDismiss: {
                        stopSession()
                    },
                    onExtend: {
                        autoStopManager.maxDuration += 300 // Add 5 minutes
                        showAutoStopWarning = false
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            if let book = selectedBook {
                startListening()
                // Extract colors for initial book
                Task {
                    await extractBookColors(book)
                }
            }
        }
        .onChange(of: selectedBook) { _, newValue in
            if let book = newValue {
                startListening()
                // Extract colors for the selected book
                Task {
                    await extractBookColors(book)
                }
            } else {
                bookColorPalette = nil
            }
        }
        .onChange(of: voiceManager.transcribedText) { oldValue, newValue in
            // Store transcriptions in session
            if !newValue.isEmpty && newValue != oldValue {
                print("[AmbientChat] New transcription: \(newValue)")
                session?.rawTranscriptions.append(newValue)
                
                // Detect cognitive patterns in real-time
                let patterns = CognitivePatternRecognizer.shared.recognizePatterns(in: newValue)
                if !patterns.isEmpty {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        detectedPatterns.append(contentsOf: patterns)
                        showPatternVisualizer = true
                    }
                    
                    // Hide visualizer after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        withAnimation {
                            showPatternVisualizer = false
                        }
                    }
                }
                
                // Process questions in real-time
                if isQuestion(newValue) && !realtimeQuestions.contains(newValue) {
                    realtimeQuestions.append(newValue)
                    Task {
                        await processQuestionInRealtime(newValue)
                    }
                }
                
                // Reset transcribed text to capture continuous speech
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    voiceManager.transcribedText = ""
                }
            }
        }
        .sheet(isPresented: $showingSummary) {
            if let processed = processedSession {
                SessionSummaryView(
                    session: processed,
                    onDismiss: {
                        showingSummary = false
                        isActive = false
                    },
                    onViewDetails: {
                        showingSummary = false
                        isActive = false
                    }
                )
            }
        }
        .sheet(isPresented: $showingBookPicker) {
            BookPickerSheet(onBookSelected: handleBookPickerSelection)
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoStopTriggered)) { notification in
            if let reason = notification.object as? String {
                print("[AmbientChat] Auto-stop triggered: \(reason)")
                stopSession()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoStopWarning)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showAutoStopWarning = true
            }
        }
        .onChange(of: voiceManager.currentAmplitude) { _, amplitude in
            // Reset silence timer when voice detected
            if amplitude > 0.01 {
                autoStopManager.resetSilenceTimer()
            }
        }
    }
    
    private var statusText: String {
        switch voiceManager.recognitionState {
        case .idle:
            return "Tap to start"
        case .listening:
            return voiceManager.transcribedText.isEmpty ? "Listening..." : "I'm listening..."
        case .processing:
            return "Processing..."
        }
    }
    
    private func handleBookPickerSelection(_ book: Book) {
        // Save current session if there's transcription
        let hasTranscriptions = !(session?.rawTranscriptions.isEmpty ?? true)
        
        if hasTranscriptions {
            // Process and save current session before switching
            Task {
                await processCurrentSessionBeforeSwitch()
                
                // Switch to new book
                await MainActor.run {
                    selectedBook = book
                    session?.book = book
                    showingBookPicker = false
                    
                    // Resume listening with new book
                    voiceManager.startAmbientListening()
                }
            }
        } else {
            // No transcriptions yet, just switch
            selectedBook = book
            session?.book = book
            showingBookPicker = false
            voiceManager.startAmbientListening()
        }
    }
    
    private func startListening() {
        // Create new session
        session = AmbientSession(startTime: Date(), book: selectedBook)
        
        // Start listening
        voiceManager.startAmbientListening()
        isRecording = true
        
        // Start auto-stop monitoring
        autoStopManager.startMonitoring()
        
        // Haptic feedback
        HapticManager.shared.mediumTap()
    }
    
    private func stopSession() {
        // Stop listening
        voiceManager.stopListening()
        isRecording = false
        
        // Stop auto-stop monitoring
        autoStopManager.stopMonitoring()
        
        // Mark session end time
        session?.endTime = Date()
        
        // Haptic feedback
        HapticManager.shared.success()
        
        // Show processing view
        withAnimation {
            showProcessingView = true
        }
        
        // Process after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            processSessionAndDismiss()
        }
    }
    
    private func processSessionAndDismiss() {
        guard let session = session else {
            withAnimation {
                isActive = false
            }
            return
        }
        
        Task {
            // Process the session
            let processed = await processAmbientSession(session)
            
            // TODO: Save to SwiftData - find existing thread or create new one
            // ChatThread and ThreadedChatMessage models have been removed
            /*
            let bookId = session.book?.localId
            let descriptor = FetchDescriptor<ChatThread>(
                predicate: bookId != nil ? #Predicate<ChatThread> { thread in
                    thread.bookId == bookId
                } : nil
            )
            
            // Create or update thread on main actor
            let chatThread = await MainActor.run {
                let existingThreads = try? modelContext.fetch(descriptor)
                let chatThread: ChatThread
                
                if let existingThread = existingThreads?.first {
                    // Update existing thread with new session data
                    chatThread = existingThread
                    chatThread.isAmbientSession = true
                    chatThread.capturedItems += processed.quotes.count + processed.notes.count + processed.questions.count
                    chatThread.sessionDuration += session.duration
                    chatThread.lastMessageDate = session.endTime ?? Date()
                    
                    // Add a message summarizing the ambient session
                    let summaryMessage = ThreadedChatMessage(
                        content: "Ambient Session (\(processed.formattedDuration))\n\n" +
                                "Captured: \(processed.quotes.count) quotes, \(processed.notes.count) notes, \(processed.questions.count) questions\n\n" +
                                processed.summary,
                        isUser: false,
                        timestamp: session.endTime ?? Date()
                    )
                    chatThread.messages.append(summaryMessage)
                } else {
                    // Create new thread for this book
                    chatThread = ChatThread(ambientSession: session, processedData: processed)
                    modelContext.insert(chatThread)
                }
                
                return chatThread
            }
            */
            
            // TODO: Add quotes as messages in the chat thread
            // ChatThread and ThreadedChatMessage models have been removed
            /*
            for quote in processed.quotes {
                await MainActor.run {
                    let quoteMessage = ThreadedChatMessage(
                        content: "\u{201C}\(quote.text)\u{201D}",
                        isUser: true,
                        timestamp: quote.timestamp,
                        bookTitle: session.book?.title,
                        bookAuthor: session.book?.author
                    )
                    chatThread.messages.append(quoteMessage)
                }
            }
            */
            
            // TODO: Add notes as messages in the chat thread
            // ChatThread and ThreadedChatMessage models have been removed
            /*
            for note in processed.notes {
                await MainActor.run {
                    let notePrefix = ""
                    let noteMessage = ThreadedChatMessage(
                        content: notePrefix + note.text,
                        isUser: true,
                        timestamp: note.timestamp,
                        bookTitle: session.book?.title,
                        bookAuthor: session.book?.author
                    )
                    chatThread.messages.append(noteMessage)
                }
            }
            */
            
            // Process questions with AI outside of MainActor.run
            for question in processed.questions {
                // TODO: Add user's question to chat on main actor
                // ChatThread and ThreadedChatMessage models have been removed
                /*
                await MainActor.run {
                    let questionMessage = ThreadedChatMessage(
                        content: question.text,
                        isUser: true,
                        timestamp: question.timestamp
                    )
                    chatThread.messages.append(questionMessage)
                }
                */
                
                // Get AI response to the question (outside MainActor)
                do {
                    let aiService = AICompanionService.shared
                    _ = try await aiService.processMessage(
                        question.text,
                        bookContext: session.book,
                        conversationHistory: []  // Empty history for now, as questions are processed independently
                    )
                    
                    // TODO: Add AI's answer to chat on main actor
                    // ChatThread and ThreadedChatMessage models have been removed
                    /*
                    await MainActor.run {
                        let answerMessage = ThreadedChatMessage(
                            content: answer,
                            isUser: false,
                            timestamp: Date()
                        )
                        chatThread.messages.append(answerMessage)
                    }
                    */
                    
                } catch {
                    print("[AmbientChat] Failed to get AI response: \(error)")
                    // TODO: Add error message if AI fails on main actor
                    // ChatThread and ThreadedChatMessage models have been removed
                    /*
                    await MainActor.run {
                        let errorMessage = ThreadedChatMessage(
                            content: "I couldn't process that question right now. Please try asking again.",
                            isUser: false,
                            timestamp: Date()
                        )
                        chatThread.messages.append(errorMessage)
                    }
                    */
                }
            }
            
            // Final save and show summary on main actor
            await MainActor.run {
                try? modelContext.save()
                
                // Show summary
                processedSession = processed
                showProcessingView = false
                showingSummary = true
            }
        }
    }
    
    private func processAmbientSession(_ session: AmbientSession) async -> ProcessedAmbientSession {
        print("[AmbientChat] Processing session with \(session.rawTranscriptions.count) transcriptions")
        
        // Combine all transcriptions into a single text for better context
        let fullTranscript = session.rawTranscriptions.joined(separator: " ")
        print("[AmbientChat] Full transcript captured [\(fullTranscript.count) characters]")
        
        // Extract quotes, notes, and questions from raw transcriptions
        var quotes: [ExtractedQuote] = []
        var notes: [ExtractedNote] = []
        var questions: [ExtractedQuestion] = []
        
        // Analyze cognitive patterns
        let cognitiveAnalysis = CognitivePatternRecognizer.shared.analyzeSessionPatterns(session.rawTranscriptions)
        
        // Process each transcription segment with cognitive pattern recognition
        for (index, transcription) in session.rawTranscriptions.enumerated() {
            let trimmed = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            print("[AmbientChat] Processing segment \(index): \(trimmed)")
            
            // Get cognitive patterns for this segment
            let patterns = CognitivePatternRecognizer.shared.recognizePatterns(in: trimmed)
            let primaryPattern = patterns.first?.pattern
            
            // Improved QUOTE detection
            var foundQuote = false
            let lowercased = trimmed.lowercased()
            
            // Check for explicit quote indicators FIRST
            if lowercased.starts(with: "quote:") ||
               lowercased.contains("save this quote") ||
               lowercased.contains("i want to quote") ||
               lowercased.contains("remember this quote") ||
               lowercased.contains("here's a quote") ||
               lowercased.contains("the book says") ||
               lowercased.contains("the author says") ||
               lowercased.contains("it says") ||
               lowercased.contains("she says") ||
               lowercased.contains("he says") ||
               lowercased.contains("they say") ||
               lowercased.contains("passage") ||
               lowercased.contains("writes") ||
               lowercased.contains("wrote") ||
               lowercased.contains("according to") {
                print("   Detected as QUOTE (by keyword)")
                foundQuote = true
                
                // Extract the actual quote text
                var quoteText = trimmed
                
                // Remove the quote indicator prefix if present
                if lowercased.starts(with: "quote:") {
                    quoteText = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                }
                
                // Clean quotation marks if present
                quoteText = cleanQuotationMarks(from: quoteText)
                
                if !quoteText.isEmpty {
                    quotes.append(ExtractedQuote(
                        text: quoteText,
                        context: session.book?.title,
                        timestamp: Date()
                    ))
                }
            }
            // Check for quotation marks as secondary indicator
            else if trimmed.contains("\"") || trimmed.contains("\u{201C}") || trimmed.contains("\u{201D}") {
                // Extract content between quotes
                let quotedContent = extractQuotedContent(from: trimmed)
                if !quotedContent.isEmpty && quotedContent.count > 10 { // At least 10 chars
                    print("   Detected as QUOTE (by quotation marks)")
                    foundQuote = true
                    quotes.append(ExtractedQuote(
                        text: quotedContent,
                        context: session.book?.title,
                        timestamp: Date()
                    ))
                }
            }
            
            // Improved QUESTION detection
            var foundQuestion = false
            if !foundQuote && (trimmed.hasSuffix("?") ||
                lowercased.starts(with: "why ") ||
                lowercased.starts(with: "how ") ||
                lowercased.starts(with: "what ") ||
                lowercased.starts(with: "when ") ||
                lowercased.starts(with: "where ") ||
                lowercased.starts(with: "who ") ||
                lowercased.starts(with: "which ") ||
                lowercased.starts(with: "can you") ||
                lowercased.starts(with: "could you") ||
                lowercased.starts(with: "would you") ||
                lowercased.starts(with: "should ") ||
                lowercased.starts(with: "is this") ||
                lowercased.starts(with: "are these") ||
                lowercased.starts(with: "do you") ||
                lowercased.starts(with: "does this") ||
                lowercased.contains("i wonder") ||
                lowercased.contains("i'm curious") ||
                lowercased.contains("i'm unsure") ||
                lowercased.contains("what does this mean") ||
                lowercased.contains("what does that mean") ||
                lowercased.contains("can you explain") ||
                lowercased.contains("could you explain") ||
                lowercased.contains("please explain") ||
                lowercased.contains("tell me about") ||
                lowercased.contains("tell me more")) {
                print("   Detected as QUESTION")
                foundQuestion = true
                questions.append(ExtractedQuestion(
                    text: trimmed,
                    context: session.book?.title,
                    timestamp: Date()
                ))
            }
            
            // Improved NOTE detection
            if !foundQuote && !foundQuestion {
                // Determine note type based on cognitive pattern and content
                var noteType: ExtractedNote.NoteType = .reflection
                
                // First check explicit note indicators
                if lowercased.starts(with: "note:") ||
                   lowercased.starts(with: "i think") ||
                   lowercased.starts(with: "i feel") ||
                   lowercased.starts(with: "i believe") ||
                   lowercased.starts(with: "my thought") ||
                   lowercased.starts(with: "my opinion") ||
                   lowercased.contains("reminds me of") ||
                   lowercased.contains("this makes me think") {
                    noteType = .reflection
                    print("   Detected as NOTE - reflection (by keyword)")
                } else if lowercased.contains("similar to") ||
                          lowercased.contains("connects to") ||
                          lowercased.contains("relates to") ||
                          lowercased.contains("like when") ||
                          lowercased.contains("reminds me") {
                    noteType = .connection
                    print("   Detected as NOTE - connection (by keyword)")
                } else if lowercased.contains("i realize") ||
                          lowercased.contains("i understand") ||
                          lowercased.contains("this shows") ||
                          lowercased.contains("this means") ||
                          lowercased.contains("insight") {
                    noteType = .insight
                    print("   Detected as NOTE - insight (by keyword)")
                } else {
                    // Fall back to cognitive pattern if available
                    switch primaryPattern {
                    case .connecting:
                        noteType = .connection
                        print("   Detected as NOTE - connection (by pattern)")
                    case .analyzing, .synthesizing, .evaluating:
                        noteType = .insight
                        print("   Detected as NOTE - insight (by pattern)")
                    case .reflecting, .creating, nil:
                        noteType = .reflection
                        print("   Detected as NOTE - reflection (by pattern)")
                    default:
                        noteType = .reflection
                        print("   Detected as NOTE - reflection (default)")
                    }
                }
                
                // Remove "Note:" prefix if present
                var noteText = trimmed
                if lowercased.starts(with: "note:") {
                    noteText = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                }
                
                notes.append(ExtractedNote(
                    text: noteText,
                    type: noteType,
                    timestamp: Date()
                ))
            }
        }
        
        print("[AmbientChat] Extracted: \(quotes.count) quotes, \(notes.count) notes, \(questions.count) questions")
        
        // Generate summary with cognitive analysis
        let summary = generateSessionSummary(session: session, quotes: quotes, notes: notes, questions: questions, cognitiveAnalysis: cognitiveAnalysis)
        
        return ProcessedAmbientSession(
            quotes: quotes,
            notes: notes,
            questions: questions,
            summary: summary,
            duration: session.duration
        )
    }
    
    private func generateSessionSummary(session: AmbientSession, quotes: [ExtractedQuote], notes: [ExtractedNote], questions: [ExtractedQuestion], cognitiveAnalysis: SessionCognitiveAnalysis) -> String {
        var summary = "Reading session"
        
        if let book = session.book {
            summary += " with \(book.title)"
        }
        
        summary += ". Captured \(quotes.count) quotes, \(notes.count) notes, and \(questions.count) questions. "
        summary += cognitiveAnalysis.summary
        
        return summary
    }
    
    private func processCurrentSessionBeforeSwitch() async {
        guard let session = session, !session.rawTranscriptions.isEmpty else { return }
        
        // Process the current session
        _ = await processAmbientSession(session)
        
        // TODO: Save to existing thread
        // ChatThread and ThreadedChatMessage models have been removed
        /*
        await MainActor.run {
            let bookId = session.book?.localId
            let descriptor = FetchDescriptor<ChatThread>(
                predicate: bookId != nil ? #Predicate<ChatThread> { thread in
                    thread.bookId == bookId
                } : nil
            )
            
            if let existingThreads = try? modelContext.fetch(descriptor),
               let existingThread = existingThreads.first {
                // Add summary message to existing thread
                let summaryMessage = ThreadedChatMessage(
                    content: "Ambient Session (\(processed.formattedDuration))\n\n" +
                            "Captured: \(processed.quotes.count) quotes, \(processed.notes.count) notes, \(processed.questions.count) questions",
                    isUser: false,
                    timestamp: Date()
                )
                existingThread.messages.append(summaryMessage)
                existingThread.capturedItems += processed.quotes.count + processed.notes.count + processed.questions.count
                existingThread.sessionDuration += session.duration
                existingThread.lastMessageDate = Date()
                
                try? modelContext.save()
            }
            
            // Clear current session transcriptions for new book
            self.session?.rawTranscriptions.removeAll()
        }
        */
    }
    
    // MARK: - Real-time Question Processing
    
    private func isQuestion(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        
        return trimmed.contains("?") ||
               lowercased.starts(with: "why") ||
               lowercased.starts(with: "how") ||
               lowercased.starts(with: "what") ||
               lowercased.starts(with: "when") ||
               lowercased.starts(with: "where") ||
               lowercased.starts(with: "who") ||
               lowercased.contains("i wonder") ||
               lowercased.contains("i'm curious") ||
               lowercased.contains("i'm unsure")
    }
    
    private func processQuestionInRealtime(_ question: String) async {
        // Get the current book context from the view
        guard let book = selectedBook else { return }
        
        do {
            // TODO: Find or create chat thread for this book
            // ChatThread and ThreadedChatMessage models have been removed
            /*
            let bookId = book.localId
            let descriptor = FetchDescriptor<ChatThread>(
                predicate: #Predicate<ChatThread> { thread in
                    thread.bookId == bookId
                }
            )
            
            // Create or find thread on main actor
            let existingThreads = try? await MainActor.run {
                try? modelContext.fetch(descriptor)
            }
            
            let chatThread: ChatThread = await MainActor.run {
                if let existingThread = existingThreads?.first {
                    return existingThread
                } else {
                    // Create new thread for this book
                    let newThread = ChatThread(book: book)
                    newThread.isAmbientSession = true
                    modelContext.insert(newThread)
                    return newThread
                }
            }
            */
            
            // TODO: Add user's question to chat
            // ChatThread and ThreadedChatMessage models have been removed
            /*
            await MainActor.run {
                let questionMessage = ThreadedChatMessage(
                    content: question,
                    isUser: true,
                    timestamp: Date()
                )
                chatThread.messages.append(questionMessage)
                chatThread.lastMessageDate = Date()
                try? modelContext.save()
            }
            */
            
            // Get AI response asynchronously
            let aiService = AICompanionService.shared
            _ = try await aiService.processMessage(
                question,
                bookContext: book,
                conversationHistory: []
            )
            
            // TODO: Add answer on main actor
            // ChatThread and ThreadedChatMessage models have been removed
            /*
            await MainActor.run {
                let answerMessage = ThreadedChatMessage(
                    content: answer,
                    isUser: false,
                    timestamp: Date()
                )
                chatThread.messages.append(answerMessage)
                chatThread.lastMessageDate = Date()
                try? modelContext.save()
                
                // Haptic feedback for response
                HapticManager.shared.lightTap()
            }
            */
            
        } catch {
            print("[AmbientChat] Real-time question processing failed: \(error)")
        }
    }
    
    // Helper function to extract quoted content from a string
    private func extractQuotedContent(from text: String) -> String {
        // Try to find content between quotation marks
        let patterns = [
            "\"([^\"]+)\"",      // Double quotes
            "\u{201C}([^\u{201D}]+)\u{201D}", // Smart quotes
            "'([^']+)'"         // Single quotes
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        
        // If no quotes found, return empty
        return ""
    }
    
    // Helper function to clean quotation marks from text
    private func cleanQuotationMarks(from text: String) -> String {
        return text
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\u{201C}", with: "")
            .replacingOccurrences(of: "\u{201D}", with: "")
            .replacingOccurrences(of: "'", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Color Extraction
    
    private func extractBookColors(_ book: Book) async {
        guard let coverURL = book.coverImageURL,
              let url = URL(string: coverURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                let extractor = OKLABColorExtractor()
                let palette = try await extractor.extractPalette(from: image, imageSource: book.title)
                
                await MainActor.run {
                    self.bookColorPalette = palette
                }
            }
        } catch {
            print("Failed to extract colors for ambient chat: \(error)")
        }
    }
}

// MARK: - Minimal Processing Overlay
struct ProcessingOverlay: View {
    let session: AmbientSession?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                SimpleProgressIndicator(tintColor: .white, scale: 1.5)
                
                Text("Processing your session...")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
