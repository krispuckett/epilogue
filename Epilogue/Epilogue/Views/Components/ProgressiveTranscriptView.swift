import SwiftUI
import Combine

// MARK: - Progressive Transcript View
struct ProgressiveTranscriptView: View {
    // Text and detection
    let transcription: String
    let detectedEntities: [DetectedEntity]
    let confidence: Float
    let isProcessing: Bool
    
    // Customization
    var fontSize: CGFloat = 16
    var lineSpacing: CGFloat = 4
    var adaptiveColor: Color = DesignSystem.Colors.primaryAccent
    
    // Animation states
    @State private var displayedText: String = ""
    @State private var currentCharIndex: Int = 0
    @State private var animationTimer: Timer?
    @State private var scrollPosition: ScrollPosition = .bottom
    @State private var showSaveConfirmation: Bool = false
    @State private var pulseQuote: Bool = false
    @State private var thinkingDots: String = ""
    
    // Scroll management
    @Namespace private var bottomAnchor
    @State private var scrollProxy: ScrollViewProxy?
    @State private var userIsScrolling: Bool = false
    @State private var lastContentHeight: CGFloat = 0
    
    // Processing states
    @State private var processingEntities: Set<UUID> = []
    @State private var savedEntities: Set<UUID> = []
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: lineSpacing) {
                    // Main transcript with entity highlighting
                    HighlightedTextView(
                        text: displayedText,
                        entities: detectedEntities,
                        confidence: confidence,
                        processingEntities: processingEntities,
                        savedEntities: savedEntities,
                        fontSize: fontSize,
                        lineSpacing: lineSpacing,
                        adaptiveColor: adaptiveColor
                    )
                    .animation(DesignSystem.Animation.easeStandard, value: displayedText)
                    
                    // Processing indicators
                    if isProcessing {
                        ProcessingIndicatorView(
                            type: currentProcessingType,
                            dots: thinkingDots,
                            color: adaptiveColor
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Save confirmation
                    if showSaveConfirmation {
                        SaveConfirmationView()
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // Invisible anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchor)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollContentHeightKey.self,
                            value: geometry.size.height
                        )
                    }
                )
            }
            .overlay(alignment: .top) {
                // Fade gradient at top when scrolled
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.8),
                        Color.black.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
                .allowsHitTesting(false)
                .opacity(userIsScrolling ? 1.0 : 0.0)
                .animation(DesignSystem.Animation.easeStandard, value: userIsScrolling)
            }
            .overlay(alignment: .bottom) {
                // Fade gradient at bottom for visual polish
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .allowsHitTesting(false)
            }
            .onPreferenceChange(ScrollContentHeightKey.self) { newHeight in
                handleContentHeightChange(newHeight, proxy: proxy)
            }
            .onAppear {
                scrollProxy = proxy
                startTextAnimation()
            }
            .onDisappear {
                animationTimer?.invalidate()
            }
            .onChange(of: transcription) { _, newText in
                if newText.count > displayedText.count {
                    continueTextAnimation(from: displayedText.count)
                }
            }
            .onChange(of: detectedEntities) { _, newEntities in
                handleEntityDetection(newEntities)
            }
            .gesture(
                DragGesture()
                    .onChanged { _ in
                        userIsScrolling = true
                    }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            userIsScrolling = false
                            snapToBottomIfNeeded(proxy: proxy)
                        }
                    }
            )
        }
    }
    
    // MARK: - Text Animation
    
    private func startTextAnimation() {
        guard !transcription.isEmpty else { return }
        
        animationTimer?.invalidate()
        currentCharIndex = 0
        displayedText = ""
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            guard currentCharIndex < transcription.count else {
                timer.invalidate()
                return
            }
            
            let index = transcription.index(transcription.startIndex, offsetBy: currentCharIndex)
            displayedText.append(transcription[index])
            currentCharIndex += 1
            
            // Haptic feedback for certain characters
            if transcription[index] == "?" || transcription[index] == "!" {
                SensoryFeedback.light()
            }
        }
    }
    
    private func continueTextAnimation(from startIndex: Int) {
        animationTimer?.invalidate()
        currentCharIndex = startIndex
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            guard currentCharIndex < transcription.count else {
                timer.invalidate()
                return
            }
            
            let index = transcription.index(transcription.startIndex, offsetBy: currentCharIndex)
            displayedText.append(transcription[index])
            currentCharIndex += 1
        }
    }
    
    // MARK: - Entity Detection Handling
    
    private func handleEntityDetection(_ entities: [DetectedEntity]) {
        for entity in entities {
            guard !processingEntities.contains(entity.id) else { continue }
            
            // Mark as processing
            withAnimation(.easeIn(duration: 0.2)) {
                processingEntities.insert(entity.id)
            }
            
            // Haptic feedback based on entity type
            switch entity.type {
            case .question:
                SensoryFeedback.light()
                startThinkingAnimation()
            case .quote:
                SensoryFeedback.light()
                pulseQuoteAnimation()
            case .insight, .reflection:
                SensoryFeedback.light()
            default:
                break
            }
            
            // Simulate processing completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    processingEntities.remove(entity.id)
                    savedEntities.insert(entity.id)
                }
                
                // Show save confirmation
                if entity.type == .quote || entity.type == .note {
                    showSaveConfirmationBriefly()
                }
            }
        }
    }
    
    // MARK: - Animations
    
    private func startThinkingAnimation() {
        thinkingDots = ""
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation(DesignSystem.Animation.easeStandard) {
                if thinkingDots.count >= 3 {
                    thinkingDots = ""
                } else {
                    thinkingDots.append(".")
                }
            }
            
            if !isProcessing {
                timer.invalidate()
                thinkingDots = ""
            }
        }
    }
    
    private func pulseQuoteAnimation() {
        withAnimation(DesignSystem.Animation.easeStandard.repeatCount(3, autoreverses: true)) {
            pulseQuote = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            pulseQuote = false
        }
    }
    
    private func showSaveConfirmationBriefly() {
        withAnimation(DesignSystem.Animation.springStandard) {
            showSaveConfirmation = true
        }
        
        SensoryFeedback.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showSaveConfirmation = false
            }
        }
    }
    
    // MARK: - Scroll Management
    
    private func handleContentHeightChange(_ newHeight: CGFloat, proxy: ScrollViewProxy) {
        guard newHeight > lastContentHeight else { return }
        lastContentHeight = newHeight
        
        if !userIsScrolling {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(bottomAnchor, anchor: .bottom)
            }
        }
    }
    
    private func snapToBottomIfNeeded(proxy: ScrollViewProxy) {
        // Check if user is near bottom (within 100 points)
        // If so, snap to bottom
        withAnimation(DesignSystem.Animation.springStandard) {
            proxy.scrollTo(bottomAnchor, anchor: .bottom)
        }
    }
    
    private var currentProcessingType: ProcessingType {
        if let firstEntity = detectedEntities.first(where: { processingEntities.contains($0.id) }) {
            switch firstEntity.type {
            case .question: return .thinking
            case .quote: return .detecting
            default: return .processing
            }
        }
        return .processing
    }
}

// MARK: - Highlighted Text View
struct HighlightedTextView: View {
    let text: String
    let entities: [DetectedEntity]
    let confidence: Float
    let processingEntities: Set<UUID>
    let savedEntities: Set<UUID>
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let adaptiveColor: Color
    
    var body: some View {
        Text(createAttributedString())
            .font(.system(size: fontSize, weight: .regular, design: .rounded))
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func createAttributedString() -> AttributedString {
        var attributed = AttributedString(text)
        
        // Apply confidence-based opacity
        let opacity = confidenceOpacity(confidence)
        attributed.foregroundColor = .white.opacity(opacity)
        
        // Apply entity highlighting
        for entity in entities {
            guard let range = attributed.range(of: entity.text) else { continue }
            
            // Base styling
            let color = entityColor(for: entity.type)
            attributed[range].foregroundColor = color.opacity(opacity)
            
            // Processing state
            if processingEntities.contains(entity.id) {
                attributed[range].backgroundColor = color.opacity(0.1)
                attributed[range].font = .system(size: fontSize, weight: .semibold, design: .rounded)
            }
            
            // Saved state
            if savedEntities.contains(entity.id) {
                attributed[range].underlineStyle = Text.LineStyle(
                    pattern: .solid,
                    color: color.opacity(0.3)
                )
            }
            
            // Low confidence dashed underline
            if entity.confidence < 0.5 {
                attributed[range].underlineStyle = Text.LineStyle(
                    pattern: .dash,
                    color: color.opacity(0.3)
                )
            }
        }
        
        return attributed
    }
    
    private func confidenceOpacity(_ confidence: Float) -> Double {
        if confidence > 0.8 {
            return 1.0
        } else if confidence > 0.5 {
            return 0.8
        } else {
            return 0.6
        }
    }
    
    private func entityColor(for type: EntityType) -> Color {
        switch type {
        case .question:
            return .blue
        case .quote:
            return .green
        case .insight, .reflection:
            return DesignSystem.Colors.primaryAccent // Orange
        case .note:
            return .purple
        case .unknown:
            return .white
        }
    }
}

// MARK: - Processing Indicator View
struct ProcessingIndicatorView: View {
    let type: ProcessingType
    let dots: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            // Icon based on type
            Image(systemName: type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(color)
                .symbolEffect(.pulse, options: .repeating, value: true)
            
            // Processing text
            Text("\(type.text)\(dots)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            
            // Inline progress indicator
            if type == .thinking {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(color)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Save Confirmation View
struct SaveConfirmationView: View {
    @State private var checkmarkScale: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
                .scaleEffect(checkmarkScale)
                .animation(DesignSystem.Animation.springStandard, value: checkmarkScale)
            
            Text("Saved")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.1))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 0.5)
                )
        )
        .onAppear {
            checkmarkScale = 1.0
        }
    }
}

// MARK: - Supporting Types
struct DetectedEntity: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let type: EntityType
    let confidence: Float
    let range: Range<String.Index>?
    
    static func == (lhs: DetectedEntity, rhs: DetectedEntity) -> Bool {
        lhs.id == rhs.id
    }
}

// Local entity type to avoid dependency issues
enum EntityType {
    case question
    case quote
    case insight
    case reflection
    case note
    case unknown
    
    init(from contentType: String) {
        switch contentType.lowercased() {
        case "question": self = .question
        case "quote": self = .quote
        case "insight": self = .insight
        case "reflection": self = .reflection
        case "note": self = .note
        default: self = .unknown
        }
    }
}

enum ProcessingType {
    case thinking
    case detecting
    case processing
    
    var text: String {
        switch self {
        case .thinking: return "Thinking"
        case .detecting: return "Detecting quote"
        case .processing: return "Processing"
        }
    }
    
    var icon: String {
        switch self {
        case .thinking: return "brain"
        case .detecting: return "quote.bubble"
        case .processing: return "gearshape.2"
        }
    }
}

enum ScrollPosition {
    case top
    case middle
    case bottom
}

// MARK: - Preference Keys
struct ScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ProgressiveTranscriptView(
            transcription: "What is the meaning of life? I love this quote: 'To be or not to be, that is the question.' This is a profound insight about human nature.",
            detectedEntities: [
                DetectedEntity(
                    text: "What is the meaning of life?",
                    type: .question,
                    confidence: 0.9,
                    range: nil
                ),
                DetectedEntity(
                    text: "To be or not to be, that is the question.",
                    type: .quote,
                    confidence: 0.95,
                    range: nil
                ),
                DetectedEntity(
                    text: "profound insight about human nature",
                    type: .insight,
                    confidence: 0.7,
                    range: nil
                )
            ],
            confidence: 0.85,
            isProcessing: false
        )
        .frame(height: 300)
        .padding()
    }
}