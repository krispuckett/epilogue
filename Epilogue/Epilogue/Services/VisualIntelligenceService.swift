import SwiftUI
import AppIntents
import Vision
import CoreImage

// MARK: - Visual Intelligence Service for iOS 26
@available(iOS 26.0, *)
@MainActor
class VisualIntelligenceService: ObservableObject {
    static let shared = VisualIntelligenceService()
    
    @Published var isProcessing = false
    @Published var lastExtractedText: String?
    
    private init() {}
    
    // MARK: - Process Visual Intelligence Content
    func processVisualContent(_ descriptor: SemanticContentDescriptor) async throws -> [TextSearchResult] {
        guard let pixelBuffer = descriptor.pixelBuffer else { 
            return []
        }
        
        // Extract text from the image
        let extractedText = try await extractTextFromPixelBuffer(pixelBuffer)
        
        await MainActor.run {
            self.lastExtractedText = extractedText
            self.isProcessing = false
        }
        
        // Create search results for quotes and questions
        var results: [TextSearchResult] = []
        
        if !extractedText.isEmpty {
            // Detect if it's a quote
            let isQuote = detectQuoteCharacteristics(extractedText)
            
            if isQuote {
                results.append(TextSearchResult(
                    id: UUID().uuidString,
                    text: extractedText,
                    type: .quote,
                    confidence: 0.9
                ))
            } else {
                results.append(TextSearchResult(
                    id: UUID().uuidString,
                    text: extractedText,
                    type: .question,
                    confidence: 0.8
                ))
            }
        }
        
        return results
    }
    
    // MARK: - Text Extraction
    private func extractTextFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) async throws -> String {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
            throw VisualIntelligenceError.imageConversionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Sort and extract text properly
                let sortedObservations = observations.sorted { first, second in
                    let firstY = 1.0 - first.boundingBox.origin.y - first.boundingBox.height
                    let secondY = 1.0 - second.boundingBox.origin.y - second.boundingBox.height
                    
                    if abs(firstY - secondY) > 0.02 {
                        return firstY < secondY
                    } else {
                        return first.boundingBox.origin.x < second.boundingBox.origin.x
                    }
                }
                
                let text = sortedObservations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Quote Detection
    private func detectQuoteCharacteristics(_ text: String) -> Bool {
        let quoteIndicators = [
            text.contains("\""),
            text.contains("\u{201C}"), // Left double quotation mark
            text.contains("\u{201D}"), // Right double quotation mark
            text.contains("'"),
            text.contains("\u{2019}"), // Right single quotation mark
            text.hasPrefix("—"),
            text.hasSuffix("."),
            text.hasSuffix("!"),
            text.hasSuffix("?")
        ]
        
        let indicatorCount = quoteIndicators.filter { $0 }.count
        let wordCount = text.split(separator: " ").count
        
        return indicatorCount >= 2 || (wordCount >= 15 && wordCount <= 100)
    }
}

// MARK: - Text Search Result
struct TextSearchResult: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Text Result")
    static let defaultQuery = TextSearchQuery()
    
    let id: String
    let text: String
    let type: ResultType
    let confidence: Double
    
    enum ResultType {
        case quote
        case question
    }
    
    var displayRepresentation: DisplayRepresentation {
        let title = type == .quote ? "Quote" : "Question"
        let subtitle = String(text.prefix(100))
        
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)...",
            image: type == .quote ? 
                .init(systemName: "quote.bubble.fill") : 
                .init(systemName: "questionmark.circle.fill")
        )
    }
}

// MARK: - Text Search Query
struct TextSearchQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TextSearchResult] {
        // Implementation for fetching specific results by ID
        return []
    }
    
    func suggestedEntities() async throws -> [TextSearchResult] {
        // Return recent or suggested text captures
        return []
    }
}

// MARK: - Visual Intelligence Intent
@available(iOS 26.0, *)
struct VisualIntelligenceIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture Text with Visual Intelligence"
    static let description = IntentDescription("Extract text from images using Visual Intelligence")
    
    @Parameter(title: "Content")
    var content: SemanticContentDescriptor
    
    func perform() async throws -> some IntentResult & ReturnsValue<[TextSearchResult]> {
        let results = try await VisualIntelligenceService.shared.processVisualContent(content)
        return .result(value: results)
    }
}

// MARK: - Visual Intelligence Query
@available(iOS 26.0, *)
struct EpilogueVisualIntelligenceQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [TextSearchResult] {
        return try await VisualIntelligenceService.shared.processVisualContent(input)
    }
}

// MARK: - Error Types
enum VisualIntelligenceError: Error {
    case imageConversionFailed
    case textExtractionFailed
    case noContentFound
}

// MARK: - Semantic Content Descriptor (Mock for iOS 26)
// This would be provided by the iOS 26 SDK
struct SemanticContentDescriptor {
    let pixelBuffer: CVPixelBuffer?
    let searchLabels: [String]?
    let confidence: Double
}