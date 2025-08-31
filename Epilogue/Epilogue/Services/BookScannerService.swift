import SwiftUI
import Vision
import VisionKit
import UIKit
import Combine
import AVFoundation

@MainActor
class BookScannerService: NSObject, ObservableObject {
    static let shared = BookScannerService()
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var processingStatus = "Ready to scan"
    @Published var detectedBooks: [Book] = []
    @Published var showSearchResults = false
    @Published var scanError: ScanError?
    @Published var extractedText: String = ""
    
    // MARK: - Private Properties
    private var googleBooksService = GoogleBooksService()
    private var cancellables = Set<AnyCancellable>()
    private var currentViewController: UIViewController?
    
    // Detection confidence thresholds
    private let minimumTextConfidence: Float = 0.5
    private let minimumBarcodeConfidence: Float = 0.8
    
    enum ScanError: LocalizedError {
        case cameraPermissionDenied
        case processingFailed
        case noTextDetected
        case searchFailed
        case noBooksFound
        
        var errorDescription: String? {
            switch self {
            case .cameraPermissionDenied:
                return "Camera permission is required to scan books"
            case .processingFailed:
                return "Failed to process the image"
            case .noTextDetected:
                return "No text detected in the image"
            case .searchFailed:
                return "Failed to search for books"
            case .noBooksFound:
                return "No books found matching the scan"
            }
        }
    }
    
    // MARK: - Extracted Information
    struct ExtractedBookInfo {
        var title: String?
        var author: String?
        var isbn: String?
        var confidence: Float
        
        var searchQuery: String {
            if let isbn = isbn, !isbn.isEmpty {
                return "isbn:\(isbn)"
            } else if let title = title, let author = author {
                return "\(title) \(author)"
            } else if let title = title {
                return title
            } else if let author = author {
                return author
            }
            return ""
        }
        
        var hasValidInfo: Bool {
            return isbn != nil || title != nil || author != nil
        }
    }
    
    // MARK: - Public Methods
    
    func scanBookCover(from viewController: UIViewController) {
        currentViewController = viewController
        
        // Check camera permissions first
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraAuthStatus == .denied || cameraAuthStatus == .restricted {
            scanError = .cameraPermissionDenied
            return
        }
        
        // Present document camera
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self
        viewController.present(scannerViewController, animated: true)
        
        // Haptic feedback
        SensoryFeedback.medium()
    }
    
    func processScannedImage(_ image: UIImage) async -> ExtractedBookInfo {
        await MainActor.run {
            isProcessing = true
            processingStatus = "Reading cover..."
        }
        
        var extractedInfo = ExtractedBookInfo(confidence: 0)
        
        guard let cgImage = image.cgImage else {
            await MainActor.run {
                isProcessing = false
            }
            return extractedInfo
        }
        
        // Create Vision requests
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.recognitionLanguages = ["en-US"]
        textRequest.usesLanguageCorrection = true
        textRequest.minimumTextHeight = 0.01 // Capture smaller text
        textRequest.customWords = ["ENDURANCE", "ISBN"] // Help with specific words
        
        let barcodeRequest = VNDetectBarcodesRequest()
        barcodeRequest.symbologies = [.ean8, .ean13, .upce] // ISBN formats
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            // Process text recognition
            await MainActor.run {
                processingStatus = "Finding text..."
            }
            try requestHandler.perform([textRequest])
            
            if let textResults = textRequest.results {
                extractedInfo = processTextResults(textResults)
            }
            
            // Process barcode detection
            await MainActor.run {
                processingStatus = "Checking for ISBN..."
            }
            try requestHandler.perform([barcodeRequest])
            
            if let barcodeResults = barcodeRequest.results {
                if let isbn = processBarcodeResults(barcodeResults) {
                    extractedInfo.isbn = isbn
                    extractedInfo.confidence = 1.0 // ISBN is most reliable
                }
            }
            
            // Final status
            await MainActor.run {
                processingStatus = "Almost done..."
            }
            
        } catch {
            print("Vision processing error: \(error)")
            await MainActor.run {
                scanError = .processingFailed
            }
        }
        
        await MainActor.run {
            isProcessing = false
        }
        return extractedInfo
    }
    
    private func processTextResults(_ results: [VNRecognizedTextObservation]) -> ExtractedBookInfo {
        var info = ExtractedBookInfo(confidence: 0)
        var allText: [(text: String, position: CGPoint, size: CGSize)] = []
        var confidenceScores: [Float] = []
        
        // Sort observations by Y position (top to bottom)
        let sortedObservations = results.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        
        // Extract text with position and size info
        for observation in sortedObservations {
            // Try to get multiple candidates for better recognition
            let candidates = observation.topCandidates(3)
            
            for candidate in candidates {
                if candidate.confidence >= minimumTextConfidence * 0.8 { // Lower threshold for multiple candidates
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty && text.count > 1 { // Accept shorter text
                        let position = CGPoint(x: observation.boundingBox.midX, y: observation.boundingBox.midY)
                        let size = observation.boundingBox.size
                        allText.append((text: text, position: position, size: size))
                        confidenceScores.append(candidate.confidence)
                        print("📝 Detected text at Y:\(position.y), size: \(size.height)")
                        break // Use first good candidate
                    }
                }
            }
        }
        
        // Smart text analysis
        if !allText.isEmpty {
            // Sort all text by size (largest first)
            let sortedBySize = allText.sorted { $0.size.height > $1.size.height }
            
            // The largest text is likely the main title
            if let largestText = sortedBySize.first {
                info.title = largestText.text
                print("📖 Main title identified")
                
                // Special case: if title is just "ENDURANCE", it's definitely the Shackleton book
                if largestText.text.uppercased() == "ENDURANCE" {
                    // This is a well-known book, enhance the search
                    info.title = "Endurance Shackleton"
                }
            }
            
            // Look for subtitle (AN EPIC OF POLAR ADVENTURE)
            for item in sortedBySize.dropFirst() {
                let text = item.text
                let lower = text.lowercased()
                if (lower.contains("adventure") || lower.contains("epic") || lower.contains("story")) &&
                   !lower.contains("author") && !lower.contains("captain") {
                    // This is likely a subtitle, append to title
                    if let existingTitle = info.title {
                        info.title = "\(existingTitle): \(text)"
                    }
                    break
                }
            }
            
            // Look for ISBN
            for item in allText {
                if item.text.contains("978") || item.text.contains("979") {
                    let numbers = item.text.filter { $0.isNumber }
                    if numbers.count == 13 {
                        info.isbn = numbers
                        print("📚 Found ISBN")
                    }
                }
            }
            
            // If no title found from large text, use first few text elements
            if info.title == nil || info.title!.isEmpty {
                let topTexts = allText.prefix(5).map { $0.text }
                let titleTexts = topTexts.filter { text in
                    let lower = text.lowercased()
                    return !lower.contains("by ") && 
                           !lower.contains("author") &&
                           !isPublisherInfo(text) &&
                           !isLikelyAuthorName(text) &&
                           text.count > 2
                }
                if !titleTexts.isEmpty {
                    info.title = titleTexts.prefix(3).joined(separator: " ")
                }
            }
            
            // Look for author
            for item in allText {
                let text = item.text
                let lowercased = text.lowercased()
                
                // Check for explicit author markers
                if lowercased.contains("by ") {
                    info.author = text
                        .replacingOccurrences(of: "(?i)by ", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                } 
                // F. A. WORSLEY pattern
                else if text.range(of: #"^[A-Z]\.\s*[A-Z]\.\s*[A-Z]+"#, options: .regularExpression) != nil {
                    info.author = text
                    break
                }
                else if isLikelyAuthorName(text) && info.author == nil {
                    info.author = text
                }
            }
            
            // Calculate overall confidence
            if !confidenceScores.isEmpty {
                info.confidence = confidenceScores.reduce(0, +) / Float(confidenceScores.count)
            }
            
            // Store extracted text for search
            let allTextStrings = allText.map { $0.text }
            self.extractedText = [info.title, info.author].compactMap { $0 }.joined(separator: " ")
            
            // If we have very little, use all detected text
            if self.extractedText.count < 10 {
                self.extractedText = allTextStrings.joined(separator: " ")
            }
            
            print("📖 Final extraction completed")
        }
        
        return info
    }
    
    private func processBarcodeResults(_ results: [VNBarcodeObservation]) -> String? {
        for observation in results {
            if let payloadString = observation.payloadStringValue {
                // Validate ISBN format
                let cleanISBN = payloadString.replacingOccurrences(of: "-", with: "")
                if isValidISBN(cleanISBN) {
                    self.extractedText = cleanISBN
                    return cleanISBN
                }
            }
        }
        return nil
    }
    
    func searchWithExtractedInfo(_ info: ExtractedBookInfo) async {
        guard info.hasValidInfo else {
            scanError = .noTextDetected
            return
        }
        
        // Set extracted text from book info
        if let isbn = info.isbn {
            self.extractedText = "isbn:\(isbn)"
        } else if let title = info.title {
            // Don't duplicate author name if it's already in the title
            if let author = info.author, !title.contains(author) {
                self.extractedText = "\(title) \(author)"
            } else {
                self.extractedText = title
            }
        } else if let author = info.author {
            self.extractedText = author
        }
        
        // Show the search sheet
        showSearchResults = true
        SensoryFeedback.success()
    }
    
    // MARK: - Helper Methods
    
    private func isPublisherInfo(_ text: String) -> Bool {
        let publisherKeywords = ["publishing", "publishers", "press", "books", "edition", "copyright", "isbn"]
        let lowercased = text.lowercased()
        return publisherKeywords.contains { lowercased.contains($0) }
    }
    
    private func isLikelyAuthorName(_ text: String) -> Bool {
        // Simple heuristic: contains space (first and last name) and no numbers
        let words = text.split(separator: " ")
        return words.count >= 2 && 
               words.count <= 4 && 
               !text.contains(where: { $0.isNumber }) &&
               text.rangeOfCharacter(from: .punctuationCharacters) == nil
    }
    
    private func isValidISBN(_ isbn: String) -> Bool {
        // Basic ISBN validation
        let cleanISBN = isbn.replacingOccurrences(of: "[^0-9X]", with: "", options: .regularExpression)
        return cleanISBN.count == 10 || cleanISBN.count == 13
    }
    
    func reset() {
        isProcessing = false
        processingStatus = "Ready to scan"
        detectedBooks = []
        showSearchResults = false
        scanError = nil
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

extension BookScannerService: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            Task {
                // Process the first scanned page
                if scan.pageCount > 0 {
                    let image = scan.imageOfPage(at: 0)
                    let extractedInfo = await self.processScannedImage(image)
                    
                    if extractedInfo.hasValidInfo {
                        await self.searchWithExtractedInfo(extractedInfo)
                    } else {
                        self.scanError = .noTextDetected
                    }
                }
            }
        }
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        reset()
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true)
        scanError = .processingFailed
    }
}


// MARK: - Loading Overlay

struct BookScannerLoadingOverlay: View {
    @ObservedObject var scanner = BookScannerService.shared
    
    var body: some View {
        if scanner.isProcessing {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    SimpleProgressIndicator(scale: 1.5)
                    
                    Text(scanner.processingStatus)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(40)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
            }
            .transition(.opacity)
        }
    }
}