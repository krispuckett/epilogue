import SwiftUI
import Vision
import VisionKit
import AVFoundation
import Combine

// MARK: - Live Quote Capture (iOS 26 Experimental)
/// Real-time quote capture using RecognizeDocumentsRequest
/// Zero capture delay - text highlights appear instantly as you hover
/// Access via Developer Options > Experimental Quote Capture

struct LiveQuoteCapture: View {
    @StateObject private var viewModel = LiveQuoteCaptureViewModel()
    @StateObject private var intelligence = QuoteIntelligence()

    let bookContext: Book?
    let onQuoteSaved: (String, Int?) -> Void
    let onQuestionAsked: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isGeneratingQuestion = false

    var body: some View {
        ZStack {
            // Layer 0: Pure black background
            Color.black
                .ignoresSafeArea()

            // Layer 1: Live Camera Feed
            LiveCameraView(onFrame: viewModel.processFrame)
                .ignoresSafeArea()

            // Layer 2: Text Highlights (Liquid Glass Overlay)
            TextHighlightsOverlay(
                paragraphs: viewModel.recognizedParagraphs,
                selected: viewModel.selectedParagraph,
                onSelect: { paragraph in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        viewModel.selectedParagraph = paragraph
                    }
                    // Medium haptic - "Got it"
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            )

            // Layer 3: Top Chrome (Minimal)
            VStack {
                HStack {
                    // Back button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                    }
                    .glassEffect(in: .circle)

                    Spacer()

                    // Instructions (show if no text detected yet)
                    if viewModel.recognizedParagraphs.isEmpty && !viewModel.isAnalyzing {
                        Text("Point at text")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .glassEffect(in: .capsule)
                    }

                    // Page number indicator (when detected)
                    if let page = viewModel.pageNumber {
                        Text("Page \(page)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(in: .capsule)
                    }

                    // Debug: Recognition status
                    #if DEBUG
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .clipShape(Capsule())
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)

                Spacer()
            }

            // Layer 4: Action Pills (When text selected)
            if let selected = viewModel.selectedParagraph {
                VStack {
                    Spacer()

                    LiquidGlassActionPills(
                        selectedText: selected.text,
                        onSave: {
                            saveQuote(selected)
                        },
                        onAsk: {
                            askAboutQuote(selected)
                        }
                    )
                }
            }

            // Layer 5: Analyzing overlay (only if slow)
            if viewModel.isAnalyzing {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("Reading text...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(28)
                    .glassEffect(in: .rect(cornerRadius: 20))
                }
                .transition(.opacity)
            }

            // Layer 6: Generating question overlay
            if isGeneratingQuestion {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                            .scaleEffect(1.2)

                        Text("Generating question...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(28)
                    .glassEffect(in: .rect(cornerRadius: 20))
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            #if DEBUG
            print("🎥 [LIVE QUOTE] ========================================")
            print("🎥 [LIVE QUOTE] VIEW APPEARED")
            print("🎥 [LIVE QUOTE] Book context: \(bookContext?.title ?? "nil")")
            print("🎥 [LIVE QUOTE] Camera should be starting...")
            print("🎥 [LIVE QUOTE] ========================================")
            #endif
        }
    }

    private func saveQuote(_ textBlock: TextBlock) {
        // Success haptic
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        #if DEBUG
        print("💾 [LIVE QUOTE] Saving: \(textBlock.text.prefix(50))...")
        #endif

        // Save with context
        onQuoteSaved(textBlock.text, viewModel.pageNumber)

        // Smooth dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            dismiss()
        }
    }

    private func askAboutQuote(_ textBlock: TextBlock) {
        Task {
            isGeneratingQuestion = true

            // Generate smart question using AI
            let question = await intelligence.generateSmartQuestion(
                for: textBlock.text,
                bookContext: bookContext,
                useAI: true
            )

            #if DEBUG
            print("🤔 [LIVE QUOTE] Asking: \(question)")
            #endif

            await MainActor.run {
                isGeneratingQuestion = false

                // Medium haptic
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                // Ask in ambient mode
                onQuestionAsked(question)

                // Smooth dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Live Quote Capture View Model

@MainActor
class LiveQuoteCaptureViewModel: ObservableObject {
    @Published var recognizedParagraphs: [TextBlock] = []
    @Published var selectedParagraph: TextBlock?
    @Published var pageNumber: Int?
    @Published var isAnalyzing = false
    @Published var recognitionConfidence: Float = 0.0

    private let recognitionService = DocumentRecognitionService(configuration: .bookScanning)
    private var hasTriggeredHaptic = false
    private var frameCount = 0

    func processFrame(_ pixelBuffer: CVPixelBuffer) async {
        frameCount += 1

        // Process every 5th frame for optimal performance
        guard frameCount % 5 == 0 else { return }

        // Show analyzing state on first frame
        if frameCount == 5 {
            isAnalyzing = true
        }

        do {
            // Use DocumentRecognitionService (iOS 26 enhanced)
            let document = try await recognitionService.recognizeDocument(from: pixelBuffer)

            await MainActor.run {
                // Hide analyzing once we have results
                if !document.isEmpty {
                    isAnalyzing = false
                }

                // Convert DocumentParagraph to TextBlock
                self.recognizedParagraphs = document.paragraphs.map { paragraph in
                    TextBlock(
                        text: paragraph.text,
                        bounds: paragraph.bounds,
                        confidence: paragraph.confidence
                    )
                }

                // Update page number
                self.pageNumber = document.pageNumber

                // Update overall confidence
                self.recognitionConfidence = document.confidence

                // Gentle haptic when text first appears
                if !recognizedParagraphs.isEmpty && !hasTriggeredHaptic {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
                    hasTriggeredHaptic = true

                    #if DEBUG
                    print("✅ [LIVE QUOTE] Detected \(recognizedParagraphs.count) paragraphs (confidence: \(String(format: "%.1f", document.confidence * 100))%)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("❌ [LIVE QUOTE] Recognition error: \(error)")
            #endif

            await MainActor.run {
                isAnalyzing = false
            }
        }
    }
}

// MARK: - Text Block Model

struct TextBlock: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let bounds: CGRect  // Normalized 0-1 coordinates
    let confidence: Float

    static func == (lhs: TextBlock, rhs: TextBlock) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    LiveQuoteCapture(
        bookContext: nil,
        onQuoteSaved: { text, page in
            print("Saved: \(text)")
        },
        onQuestionAsked: { question in
            print("Asked: \(question)")
        }
    )
}
