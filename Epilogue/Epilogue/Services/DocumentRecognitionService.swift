import Foundation
import Vision
import CoreImage
import AVFoundation

// MARK: - Document Recognition Service
/// iOS 26 RecognizeDocumentsRequest wrapper
/// Provides structured document understanding with paragraphs, tables, and detected data

@MainActor
class DocumentRecognitionService {

    // MARK: - Configuration

    struct Configuration {
        var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
        var languages: [String] = ["en"]
        var minimumTextHeight: Float = 0.01  // 1% of image height
        var usesLanguageCorrection: Bool = true
        var confidenceThreshold: Float = 0.5

        static let bookScanning = Configuration(
            recognitionLevel: .accurate,
            languages: ["en", "es", "fr", "de", "it"],  // Common book languages
            minimumTextHeight: 0.01,
            usesLanguageCorrection: true,
            confidenceThreshold: 0.6  // Higher for book quality
        )
    }

    private let configuration: Configuration
    private var documentRequest: VNRecognizeTextRequest  // Using VNRecognizeTextRequest for now

    init(configuration: Configuration = .bookScanning) {
        self.configuration = configuration

        // Configure text recognition request
        self.documentRequest = VNRecognizeTextRequest()
        self.documentRequest.recognitionLevel = configuration.recognitionLevel
        self.documentRequest.usesLanguageCorrection = configuration.usesLanguageCorrection
        self.documentRequest.minimumTextHeight = configuration.minimumTextHeight

        // Set languages if supported
        if #available(iOS 16.0, *) {
            self.documentRequest.recognitionLanguages = configuration.languages.compactMap {
                $0 as? String
            }
        }

        #if DEBUG
        print("📄 [DOC RECOGNITION] Initialized with languages: \(configuration.languages)")
        #endif
    }

    // MARK: - Recognition

    func recognizeDocument(from pixelBuffer: CVPixelBuffer) async throws -> RecognizedDocument {
        // Lock pixel buffer for reading
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }

        #if DEBUG
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        print("📹 [DOC RECOGNITION] Processing frame: \(width)x\(height)")
        #endif

        // Create handler with correct orientation (camera is landscape right)
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,  // Back camera in portrait mode
            options: [:]
        )

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([self.documentRequest])

                    guard let observations = self.documentRequest.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(throwing: RecognitionError.noResults)
                        return
                    }

                    // Process observations into structured document
                    let document = self.processObservations(observations)

                    continuation.resume(returning: document)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Processing

    private func processObservations(_ observations: [VNRecognizedTextObservation]) -> RecognizedDocument {
        // Filter by confidence
        let filtered = observations.filter { observation in
            guard let candidate = observation.topCandidates(1).first else { return false }
            return candidate.confidence >= configuration.confidenceThreshold
        }

        // Group into paragraphs using advanced algorithm
        let paragraphs = groupIntoParagraphs(filtered)

        // Extract page number from detected data
        let pageNumber = extractPageNumber(from: filtered)

        // Extract other detected data (URLs, emails, etc.)
        let detectedData = extractDetectedData(from: filtered)

        return RecognizedDocument(
            paragraphs: paragraphs,
            pageNumber: pageNumber,
            detectedData: detectedData,
            confidence: calculateAverageConfidence(filtered)
        )
    }

    // MARK: - Paragraph Grouping (Advanced Algorithm with Column Detection)

    private func groupIntoParagraphs(_ observations: [VNRecognizedTextObservation]) -> [DocumentParagraph] {
        guard !observations.isEmpty else { return [] }

        // Step 1: Detect columns by analyzing X positions
        let columns = detectColumns(observations)

        #if DEBUG
        print("📄 [DOC RECOGNITION] Detected \(columns.count) column(s)")
        #endif

        var allParagraphs: [DocumentParagraph] = []

        // Step 2: Process each column separately
        for (columnIndex, columnObservations) in columns.enumerated() {
            let columnParagraphs = groupColumnIntoParagraphs(columnObservations)
            allParagraphs.append(contentsOf: columnParagraphs)

            #if DEBUG
            print("📄 [DOC RECOGNITION] Column \(columnIndex + 1): \(columnObservations.count) lines → \(columnParagraphs.count) paragraphs")
            #endif
        }

        #if DEBUG
        print("📄 [DOC RECOGNITION] Total: \(observations.count) lines → \(allParagraphs.count) paragraphs")
        #endif

        return allParagraphs
    }

    // MARK: - Column Detection

    private func detectColumns(_ observations: [VNRecognizedTextObservation]) -> [[VNRecognizedTextObservation]] {
        guard observations.count > 1 else { return [observations] }

        // Collect all X center positions
        let xPositions = observations.map { $0.boundingBox.midX }.sorted()

        // Find gaps between X positions to detect column boundaries
        var gaps: [(position: CGFloat, gapSize: CGFloat)] = []
        for i in 0..<(xPositions.count - 1) {
            let gap = xPositions[i + 1] - xPositions[i]
            if gap > 0.15 { // Gap > 15% of width suggests column boundary
                let gapCenter = (xPositions[i] + xPositions[i + 1]) / 2
                gaps.append((gapCenter, gap))
            }
        }

        // If no significant gaps, single column
        guard !gaps.isEmpty else { return [observations] }

        // Find the most significant gap (likely the main column divider)
        let sortedGaps = gaps.sorted { $0.gapSize > $1.gapSize }

        // Use the largest gap as the column divider (for now, support 2 columns)
        // Could be extended to support more columns by using multiple gaps
        let divider = sortedGaps[0].position

        // Split observations into columns
        let leftColumn = observations.filter { $0.boundingBox.midX < divider }
        let rightColumn = observations.filter { $0.boundingBox.midX >= divider }

        // Only return separate columns if both have content
        if leftColumn.count >= 3 && rightColumn.count >= 3 {
            return [leftColumn, rightColumn]
        }

        // Not enough evidence of two columns, treat as single column
        return [observations]
    }

    // MARK: - Single Column Paragraph Grouping

    private func groupColumnIntoParagraphs(_ observations: [VNRecognizedTextObservation]) -> [DocumentParagraph] {
        guard !observations.isEmpty else { return [] }

        // Sort by reading order within column (top to bottom)
        let sorted = observations.sorted { obs1, obs2 in
            // Vision uses bottom-left origin, higher Y = higher on page
            obs1.boundingBox.midY > obs2.boundingBox.midY
        }

        var paragraphs: [DocumentParagraph] = []
        var currentGroup: [VNRecognizedTextObservation] = []
        var lastY: CGFloat = 0
        var lastHeight: CGFloat = 0

        for observation in sorted {
            let y = observation.boundingBox.midY
            let height = observation.boundingBox.height

            // Calculate gap from previous line
            let gap = lastY - y - lastHeight

            // Start new paragraph if:
            // 1. First line
            // 2. Gap > 1.5x line height (paragraph break)
            let isNewParagraph = currentGroup.isEmpty || gap > (lastHeight * 1.5)

            if isNewParagraph {
                // Save previous paragraph
                if !currentGroup.isEmpty {
                    paragraphs.append(createParagraph(from: currentGroup))
                }
                currentGroup = [observation]
            } else {
                currentGroup.append(observation)
            }

            lastY = y
            lastHeight = height
        }

        // Add last paragraph
        if !currentGroup.isEmpty {
            paragraphs.append(createParagraph(from: currentGroup))
        }

        return paragraphs
    }

    private func createParagraph(from observations: [VNRecognizedTextObservation]) -> DocumentParagraph {
        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")

        // Calculate combined bounding box
        var minX: CGFloat = 1.0
        var minY: CGFloat = 1.0
        var maxX: CGFloat = 0.0
        var maxY: CGFloat = 0.0

        for obs in observations {
            let box = obs.boundingBox
            minX = min(minX, box.minX)
            minY = min(minY, box.minY)
            maxX = max(maxX, box.maxX)
            maxY = max(maxY, box.maxY)
        }

        let bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        // Average confidence
        let avgConfidence = observations
            .compactMap { $0.topCandidates(1).first?.confidence }
            .reduce(0, +) / Float(observations.count)

        return DocumentParagraph(
            text: text,
            bounds: bounds,
            confidence: avgConfidence,
            lineCount: observations.count
        )
    }

    // MARK: - Data Extraction

    private func extractPageNumber(from observations: [VNRecognizedTextObservation]) -> Int? {
        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string else { continue }

            // Look for standalone numbers
            let cleaned = text.trimmingCharacters(in: .whitespaces)
            if let number = Int(cleaned), number > 0 && number < 10000 {
                // Page numbers typically at top or bottom
                let y = observation.boundingBox.minY
                if y > 0.85 || y < 0.15 {
                    return number
                }
            }
        }
        return nil
    }

    private func extractDetectedData(from observations: [VNRecognizedTextObservation]) -> [DetectedData] {
        var detected: [DetectedData] = []

        for observation in observations {
            guard let text = observation.topCandidates(1).first?.string else { continue }

            // Detect URLs
            if let url = detectURL(in: text) {
                detected.append(.url(url))
            }

            // Detect dates (simple pattern)
            if let date = detectDate(in: text) {
                detected.append(.date(date))
            }
        }

        return detected
    }

    private func detectURL(in text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches?.first.flatMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private func detectDate(in text: String) -> String? {
        // Simple date pattern matching
        let pattern = #"\d{1,2}/\d{1,2}/\d{2,4}"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let matches = regex?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches?.first.flatMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private func calculateAverageConfidence(_ observations: [VNRecognizedTextObservation]) -> Float {
        guard !observations.isEmpty else { return 0 }

        let sum = observations
            .compactMap { $0.topCandidates(1).first?.confidence }
            .reduce(0, +)

        return sum / Float(observations.count)
    }
}

// MARK: - Models

struct RecognizedDocument {
    let paragraphs: [DocumentParagraph]
    let pageNumber: Int?
    let detectedData: [DetectedData]
    let confidence: Float

    var isEmpty: Bool {
        paragraphs.isEmpty
    }
}

struct DocumentParagraph: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let bounds: CGRect  // Normalized 0-1
    let confidence: Float
    let lineCount: Int

    static func == (lhs: DocumentParagraph, rhs: DocumentParagraph) -> Bool {
        lhs.id == rhs.id
    }
}

enum DetectedData {
    case url(String)
    case email(String)
    case phoneNumber(String)
    case date(String)
}

enum RecognitionError: Error {
    case invalidBuffer
    case noResults
    case processingFailed
}
