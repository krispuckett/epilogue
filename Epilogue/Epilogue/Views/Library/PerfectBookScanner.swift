import SwiftUI
import VisionKit
import AVFoundation
import Vision
import Combine

/// Perfect Book Scanner - Optimized unified scanner with all features
/// - ISBN barcode scanning with instant auto-add
/// - Book cover text recognition
/// - Spine title recognition with multi-rotation
/// - Liquid glass toast notifications
/// - Battery optimizations
/// - Duplicate prevention with time-based throttling
@available(iOS 16.0, *)
struct PerfectBookScanner: View {
    let onBookAdded: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = ScannerCoordinator()
    @State private var showingManualSearch = false
    @State private var manualSearchQuery = ""
    @State private var showingISBNInput = false
    @State private var isbnInput = ""

    var body: some View {
        ZStack {
            // Check DataScanner availability
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                // Full-screen camera with DataScanner - AUTO MODE (scans everything)
                PerfectDataScannerRepresentable(
                    recognizedDataTypes: [
                        .barcode(symbologies: [.ean13, .ean8, .upce, .code128]),
                        .text(languages: ["en-US", "en-GB"])
                    ],
                    recognizesMultipleItems: true,  // Detect multiple items
                    isHighFrameRateTrackingEnabled: true,
                    isHighlightingEnabled: true,
                    qualityLevel: .balanced,  // Good balance for both barcodes and text
                    onScannedItems: { items in
                        handleScannedItems(items)
                    }
                )
                .ignoresSafeArea()

                // Scanner UI Overlay (only when DataScanner is available)
                scannerUIOverlay
            } else {
                // Fallback view
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)

                    Text("DataScanner Not Available")
                        .font(.title2.bold())

                    Text("This device doesn't support live scanning. Using fallback scanner...")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Button("Dismiss") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .onAppear {
                    #if DEBUG
                    print("❌ DataScanner not available")
                    #endif
                    #if DEBUG
                    print("   isSupported: \(DataScannerViewController.isSupported)")
                    #endif
                    #if DEBUG
                    print("   isAvailable: \(DataScannerViewController.isAvailable)")
                    #endif
                }
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $showingManualSearch) {
            BookSearchSheet(
                searchQuery: manualSearchQuery,
                onBookSelected: { book in
                    coordinator.stageBook(book)  // ← Stage instead of adding
                    SensoryFeedback.success()
                    showingManualSearch = false
                    manualSearchQuery = ""
                }
            )
        }
        .alert("Enter ISBN", isPresented: $showingISBNInput) {
            TextField("ISBN (10 or 13 digits)", text: $isbnInput)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)

            Button("Cancel", role: .cancel) {
                isbnInput = ""
            }

            Button("Search") {
                let cleanedISBN = isbnInput.filter { $0.isNumber }
                if !cleanedISBN.isEmpty {
                    Task {
                        await searchISBN(cleanedISBN)
                    }
                }
                isbnInput = ""
            }
        } message: {
            Text("Enter the ISBN number from the back of the book (works without barcode)")
        }
        .onAppear {
            #if DEBUG
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif
            #if DEBUG
            print("🚀 PERFECT BOOK SCANNER LOADED!")
            #endif
            #if DEBUG
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif
            #if DEBUG
            print("   DataScanner.isSupported: \(DataScannerViewController.isSupported)")
            #endif
            #if DEBUG
            print("   DataScanner.isAvailable: \(DataScannerViewController.isAvailable)")
            #endif
            #if DEBUG
            print("   iOS Version: \(ProcessInfo.processInfo.operatingSystemVersion)")
            #endif
            #if DEBUG
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif

            // Show immediate visual feedback
            coordinator.statusMessage = "Scan any book - barcode, cover, or spine"

            // CHANGED: Stage books first, don't add to library yet
            coordinator.onBookFound = { book in
                #if DEBUG
                print("📚 PERFECT SCANNER - Book staged: \(book.title)")
                #endif
                coordinator.stageBook(book)  // ← Only stage, don't add yet
                SensoryFeedback.success()
            }

            // Handle batch confirm
            coordinator.onConfirmBooks = { books in
                #if DEBUG
                print("✅ Confirming \(books.count) books to library")
                #endif
                for book in books {
                    onBookAdded(book)
                }
                SensoryFeedback.success()
                dismiss()
            }
        }
    }

    // MARK: - Scanner UI Overlay

    private var scannerUIOverlay: some View {
        VStack {
                // Top bar with controls
                HStack {
                    // Close button
                    Button {
                        coordinator.cleanup()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(in: Circle())
                    }

                    Spacer()

                    // Status indicator at top (not center!)
                    HStack(spacing: 8) {
                        if coordinator.isProcessing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }

                        Text(coordinator.statusMessage)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(coordinator.isProcessing ? DesignSystem.Colors.primaryAccent.opacity(0.2) : Color.green.opacity(0.2)))
                    .clipShape(Capsule())

                    Spacer()

                    // Flashlight
                    Button {
                        coordinator.toggleTorch()
                    } label: {
                        Image(systemName: coordinator.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(coordinator.isTorchOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .glassEffect(in: Circle())
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.top, 8)

                Spacer()

                // Bottom actions
                VStack(alignment: .leading, spacing: 12) {
                    // Scanned books preview drawer (shows when tapped)
                    if coordinator.showingSessionBooks && !coordinator.scannedBooksInSession.isEmpty {
                        VStack(spacing: 0) {
                            // Drag indicator
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 36, height: 4)
                                .padding(.top, 8)
                                .padding(.bottom, 12)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Array(coordinator.scannedBooksInSession.enumerated()), id: \.element.id) { index, book in
                                        VStack(spacing: 8) {
                                            ZStack(alignment: .topTrailing) {
                                                // Book cover - use thumbnail for faster loading
                                                SharedBookCoverView(
                                                    coverURL: book.coverImageURL,
                                                    width: 80,
                                                    height: 120,
                                                    loadFullImage: false
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                                                .id("\(book.id)_\(book.coverImageURL ?? "nocache")")

                                                // Delete button
                                                Button {
                                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                        coordinator.removeBookFromSession(at: index)
                                                    }
                                                    SensoryFeedback.light()
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundStyle(.white)
                                                        .background(
                                                            Circle()
                                                                .fill(Color.red.opacity(0.9))
                                                                .frame(width: 24, height: 24)
                                                        )
                                                        .glassEffect(.regular, in: Circle())
                                                }
                                                .offset(x: 8, y: -8)
                                            }

                                            Text(book.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 80)
                                        }
                                        .transition(.asymmetric(
                                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                                            removal: .scale(scale: 0.8).combined(with: .opacity)
                                        ))
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                                .padding(.vertical, 8)
                            }
                        }
                        .glassEffect(.regular.tint(Color.green.opacity(0.1)), in: .rect(cornerRadius: 20))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                        ))
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: coordinator.showingSessionBooks)
                    }

                    VStack(spacing: 12) {
                        // Batch confirm button - only show when books are staged
                        if coordinator.booksScannedThisSession > 0 {
                            Button {
                                coordinator.confirmAllBooks()
                                SensoryFeedback.success()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Add \(coordinator.booksScannedThisSession) Book\(coordinator.booksScannedThisSession == 1 ? "" : "s") to Library")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .glassEffect(.regular.tint(Color.green.opacity(0.3)))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }

                        HStack(spacing: 12) {
                            // Session counter - tappable
                            if coordinator.booksScannedThisSession > 0 {
                                Button {
                                    coordinator.toggleSessionBooksView()
                                    SensoryFeedback.light()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: coordinator.showingSessionBooks ? "chevron.down" : "books.vertical")
                                            .foregroundStyle(.green)
                                        Text("\(coordinator.booksScannedThisSession) staged")
                                    }
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .glassEffect(.regular.tint(Color.green.opacity(0.2)))
                                    .clipShape(Capsule())
                                }
                            }

                            Spacer()

                            // ISBN input button
                            Button {
                                showingISBNInput = true
                            } label: {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(in: Circle())
                            }

                            // Manual search
                            Button {
                                showingManualSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(in: Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.bottom, 24)

        }
    }

    // MARK: - ISBN Search

    private func searchISBN(_ isbn: String) async {
        coordinator.isProcessing = true
        coordinator.statusMessage = "Searching ISBN..."

        #if DEBUG
        print("📚 Searching for ISBN: \(isbn)")
        #endif

        // Use the Google Books API to search by ISBN
        let booksService = GoogleBooksService()
        if let book = await booksService.searchBookByISBN(isbn) {
            #if DEBUG
            print("✅ Found book via ISBN: \(book.title)")
            #endif
            coordinator.stageBook(book)
            SensoryFeedback.success()
            coordinator.statusMessage = "Added \(book.title)"
        } else {
            #if DEBUG
            print("❌ No book found for ISBN: \(isbn)")
            #endif
            SensoryFeedback.error()
            coordinator.statusMessage = "ISBN not found"
        }

        coordinator.isProcessing = false

        // Reset status message after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            coordinator.statusMessage = "Scan any book - barcode, cover, or spine"
        }
    }

    private func handleScannedItems(_ items: [RecognizedItem]) {
        #if DEBUG
        print("📱 SMART SCANNER: Received \(items.count) items")
        #endif
        #if DEBUG
        print("   Is processing: \(coordinator.isProcessing)")
        #endif

        guard !coordinator.isProcessing else {
            #if DEBUG
            print("   ⚠️ Ignoring - already processing")
            #endif
            return
        }

        // SMART DETECTION: Prioritize barcodes over text
        // 1. Check for barcodes first (most accurate)
        for item in items {
            if case .barcode(let barcode) = item,
               let isbn = barcode.payloadStringValue {
                #if DEBUG
                print("   ✅ BARCODE DETECTED: \(isbn)")
                #endif
                coordinator.processBarcode(isbn)
                return  // Process barcode immediately, ignore text
            }
        }

        // 2. If no barcode, look for text (title/author)
        var bestText: String?
        var bestConfidence: Float = 0

        for item in items {
            if case .text(let text) = item {
                // Filter out short fragments and noise
                let transcript = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)

                // Smart filtering for book titles
                if isLikelyBookTitle(transcript) {
                    // Score based on: length, word count, and title-like characteristics
                    let wordCount = transcript.components(separatedBy: .whitespaces).count
                    var confidence = Float(transcript.count) * Float(wordCount)

                    // Boost confidence for title-like features
                    if transcript.contains(":") || transcript.contains("—") {
                        confidence *= 1.5  // Subtitles boost confidence
                    }

                    if wordCount >= 2 && wordCount <= 8 {
                        confidence *= 1.3  // Ideal title length
                    }

                    // Penalize all-caps or all-lowercase (likely noise)
                    if transcript == transcript.uppercased() || transcript == transcript.lowercased() {
                        confidence *= 0.5
                    }

                    if confidence > bestConfidence {
                        bestConfidence = confidence
                        bestText = transcript
                    }
                }
            }
        }

        // 3. Process best text match if found
        if let text = bestText, bestConfidence > 25 {  // Much higher threshold to reduce false positives
            #if DEBUG
            print("   ✅ TEXT DETECTED: \(text) (confidence: \(bestConfidence))")
            #endif
            coordinator.processText(text)
            return
        }

        #if DEBUG
        print("   ⏭️ No valid barcode or text found")
        #endif
    }

    // Helper to detect likely book titles
    private func isLikelyBookTitle(_ text: String) -> Bool {
        // Minimum length
        guard text.count >= 5 else { return false }

        // Filter out common noise patterns - expanded list
        let noise = [
            "penguin", "modern", "classics", "isbn", "barcode", "$", "©", "®", "™",
            "publisher", "publishing", "edition", "press", "books", "series",
            "volume", "vol", "www", "http", ".com", "cover", "jacket",
            "price", "ebook", "hardcover", "paperback", "reprint"
        ]
        let lowercased = text.lowercased()

        for pattern in noise {
            if lowercased.contains(pattern) {
                return false
            }
        }

        // Filter out URLs, emails, ISBNs
        if lowercased.contains("@") || lowercased.contains(".") || lowercased.hasPrefix("97") {
            return false
        }

        // Filter out pure numbers or text with too many numbers
        if text.filter({ $0.isNumber }).count > text.count / 3 {
            return false
        }

        // Must have at least some letters
        let letterCount = text.filter({ $0.isLetter }).count
        guard letterCount >= 5 else { return false }

        // Must have at least one space (multi-word title)
        guard text.contains(" ") else { return false }

        // Filter out very short words repeated
        let words = text.split(separator: " ")
        if words.count > 0 && words.allSatisfy({ $0.count <= 2 }) {
            return false
        }

        return true
    }
}

/// Coordinator for scanner state and book lookup
@MainActor
class ScannerCoordinator: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage = "Ready"
    @Published var isTorchOn = false
    @Published var booksScannedThisSession = 0
    @Published var scannedBooksInSession: [Book] = []
    @Published var showingSessionBooks = false

    var onBookFound: ((Book) -> Void)?
    var onConfirmBooks: (([Book]) -> Void)?  // ← New callback for batch confirm

    // Duplicate prevention
    private var scannedItems = Set<String>()
    private var lastScanTime: [String: Date] = [:]
    private let rescanDelay: TimeInterval = 3.0

    // Services
    private let booksService = EnhancedGoogleBooksService()
    private let spineRecognizer = SpineTextRecognizer()

    // CHANGED: Stage books instead of adding to library
    func stageBook(_ book: Book) {
        // Prevent duplicate staging
        guard !scannedBooksInSession.contains(where: { $0.id == book.id }) else {
            #if DEBUG
            print("⚠️ Book already staged: \(book.title)")
            #endif
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scannedBooksInSession.append(book)
            booksScannedThisSession = scannedBooksInSession.count

            // Auto-show drawer when first book is staged
            if scannedBooksInSession.count == 1 {
                showingSessionBooks = true
            }
        }

        #if DEBUG
        print("📋 Staged book: \(book.title) (total: \(booksScannedThisSession))")
        #endif
    }

    func confirmAllBooks() {
        guard !scannedBooksInSession.isEmpty else { return }

        #if DEBUG
        print("✅ Confirming \(scannedBooksInSession.count) books")
        #endif
        onConfirmBooks?(scannedBooksInSession)

        // Clear session
        scannedBooksInSession.removeAll()
        booksScannedThisSession = 0
        showingSessionBooks = false
    }

    func toggleSessionBooksView() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showingSessionBooks.toggle()
        }
    }

    func removeBookFromSession(at index: Int) {
        guard index < scannedBooksInSession.count else { return }

        let removedBook = scannedBooksInSession[index]
        #if DEBUG
        print("🗑️ Removing staged book: \(removedBook.title)")
        #endif

        scannedBooksInSession.remove(at: index)
        booksScannedThisSession = scannedBooksInSession.count

        // Auto-hide drawer if empty
        if scannedBooksInSession.isEmpty {
            showingSessionBooks = false
        }
    }

    func processBarcode(_ isbn: String) {
        let cleanISBN = sanitizeISBN(isbn)

        // Validate ISBN format
        guard isValidISBN(cleanISBN) else {
            #if DEBUG
            print("⚠️ Invalid ISBN format: \(cleanISBN)")
            #endif
            statusMessage = "Invalid barcode"
            UINotificationFeedbackGenerator().notificationOccurred(.error)

            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    self.reset()
                }
            }
            return
        }

        // Duplicate check
        guard canProcess(cleanISBN) else {
            #if DEBUG
            print("⚠️ Ignoring duplicate ISBN scan: \(cleanISBN)")
            #endif
            return
        }

        #if DEBUG
        print("📚 ISBN detected: \(cleanISBN)")
        #endif

        isProcessing = true
        statusMessage = "Looking up ISBN..."

        // Heavy haptic for detection
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        Task {
            let results = await booksService.searchBooksWithRanking(query: "isbn:\(cleanISBN)")

            await MainActor.run {
                if let book = results.first {
                    statusMessage = "Found: \(book.title)"
                    #if DEBUG
                    print("✅ Auto-adding book: \(book.title)")
                    #endif

                    // Success haptic
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    // Auto-add the book
                    onBookFound?(book)

                    // Reset after delay
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            self.reset()
                        }
                    }
                } else {
                    statusMessage = "Book not found"
                    #if DEBUG
                    print("❌ No book found for ISBN: \(cleanISBN)")
                    #endif

                    UINotificationFeedbackGenerator().notificationOccurred(.error)

                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await MainActor.run {
                            self.reset()
                        }
                    }
                }
            }
        }
    }

    func processText(_ text: String) {
        // Duplicate check
        guard canProcess(text) else { return }

        #if DEBUG
        print("📖 Text detected: \(text)")
        #endif

        isProcessing = true
        statusMessage = "Searching for book..."

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            // Try direct search first
            var searchQuery = text

            // Enhance text with spine recognizer (handles rotation/cleanup)
            if let enhancedText = await spineRecognizer.recognizeSpineText(text) {
                searchQuery = enhancedText
            }

            let results = await booksService.searchBooksWithRanking(query: searchQuery)

            await MainActor.run {
                if let book = results.first {
                    statusMessage = "Found: \(book.title)"

                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onBookFound?(book)

                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            self.reset()
                        }
                    }
                } else {
                    statusMessage = "No match found"

                    UINotificationFeedbackGenerator().notificationOccurred(.error)

                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        await MainActor.run {
                            self.reset()
                        }
                    }
                }
            }
        }
    }


    func toggleTorch() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            isTorchOn.toggle()
            device.torchMode = isTorchOn ? .on : .off
            device.unlockForConfiguration()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            #if DEBUG
            print("❌ Torch error: \(error)")
            #endif
        }
    }

    func reset() {
        isProcessing = false
        statusMessage = "Scan any book - barcode, cover, or spine"
    }

    func cleanup() {
        // Turn off torch
        if isTorchOn {
            toggleTorch()
        }
    }

    // MARK: - Duplicate Prevention

    private func canProcess(_ identifier: String) -> Bool {
        let now = Date()

        // Check if we've seen this recently
        if let lastScan = lastScanTime[identifier],
           now.timeIntervalSince(lastScan) < rescanDelay {
            return false
        }

        // Update tracking
        lastScanTime[identifier] = now
        scannedItems.insert(identifier)

        // Cleanup old entries (keep last 50)
        if lastScanTime.count > 50 {
            let sortedByDate = lastScanTime.sorted { $0.value < $1.value }
            let toRemove = sortedByDate.prefix(lastScanTime.count - 50)
            for (key, _) in toRemove {
                lastScanTime.removeValue(forKey: key)
                scannedItems.remove(key)
            }
        }

        return true
    }

    private func isValidISBN(_ isbn: String) -> Bool {
        let cleaned = isbn.filter { $0.isNumber }

        // Must be 10 or 13 digits
        guard cleaned.count == 10 || cleaned.count == 13 else {
            return false
        }

        // ISBN-13 should start with 978 or 979
        if cleaned.count == 13 {
            guard cleaned.hasPrefix("978") || cleaned.hasPrefix("979") else {
                return false
            }
        }

        return true
    }

    private func sanitizeISBN(_ isbn: String) -> String {
        let cleaned = isbn
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .filter { $0.isNumber || $0 == "X" }  // ISBN-10 can end with X

        // Convert ISBN-10 to ISBN-13 if needed
        if cleaned.count == 10 {
            return convertISBN10to13(cleaned)
        }

        return cleaned
    }

    private func convertISBN10to13(_ isbn10: String) -> String {
        // Add 978 prefix and recalculate check digit
        let base = "978" + isbn10.dropLast()

        // Calculate ISBN-13 check digit
        var sum = 0
        for (index, char) in base.enumerated() {
            if let digit = Int(String(char)) {
                sum += digit * (index % 2 == 0 ? 1 : 3)
            }
        }

        let checkDigit = (10 - (sum % 10)) % 10
        return base + String(checkDigit)
    }
}

/// Spine Text Recognizer with multi-rotation support and image preprocessing
class SpineTextRecognizer {
    // Cache for recent recognitions to avoid duplicate processing
    private var recognitionCache: [String: String] = [:]

    func recognizeSpineText(_ initialText: String) async -> String? {
        // Check cache first
        if let cached = recognitionCache[initialText] {
            return cached
        }

        // For live text from DataScanner, enhance and return
        let enhanced = enhanceSpineText(initialText)
        recognitionCache[initialText] = enhanced

        // Limit cache size
        if recognitionCache.count > 20 {
            recognitionCache.removeAll()
        }

        return enhanced
    }

    func recognizeSpineFromImage(_ image: UIImage) async -> String? {
        #if DEBUG
        print("📸 Starting multi-rotation spine recognition...")
        #endif

        var allRecognizedText: [(text: String, confidence: Float, rotation: CGFloat)] = []

        // Try multiple orientations - spine text can be rotated
        let rotations: [CGFloat] = [0, 90, 180, 270]

        for rotation in rotations {
            #if DEBUG
            print("  🔄 Trying rotation: \(rotation)°")
            #endif

            if let rotatedImage = image.rotated(by: rotation),
               let preprocessed = preprocessSpineImage(rotatedImage) {

                if let results = await performTextRecognition(on: preprocessed) {
                    for result in results {
                        allRecognizedText.append((
                            text: result.text,
                            confidence: result.confidence,
                            rotation: rotation
                        ))
                    }
                }
            }
        }

        // Sort by confidence and length
        let sorted = allRecognizedText.sorted { lhs, rhs in
            let lhsScore = Float(lhs.text.count) * lhs.confidence
            let rhsScore = Float(rhs.text.count) * rhs.confidence
            return lhsScore > rhsScore
        }

        if let best = sorted.first {
            #if DEBUG
            print("✅ Best match: '\(best.text)' (rotation: \(best.rotation)°, confidence: \(best.confidence))")
            #endif
            return best.text
        }

        #if DEBUG
        print("❌ No text recognized from spine")
        #endif
        return nil
    }

    private func enhanceSpineText(_ text: String) -> String {
        // Clean up common OCR errors for spine text
        var enhanced = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        // Remove common artifacts
        enhanced = enhanced.replacingOccurrences(of: "|", with: "I")
        enhanced = enhanced.replacingOccurrences(of: "0", with: "O") // In book titles, usually O not zero

        return enhanced
    }

    private func preprocessSpineImage(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Apply preprocessing filters to enhance text readability
        let context = CIContext()

        // 1. Increase contrast
        guard let contrast = ciImage.applyingFilter("CIColorControls", parameters: [
            "inputContrast": 1.5,
            "inputBrightness": 0.1,
            "inputSaturation": 0
        ]) as CIImage? else { return nil }

        // 2. Convert to black and white
        guard let bw = contrast.applyingFilter("CIPhotoEffectNoir") as CIImage? else { return nil }

        // 3. Sharpen text
        guard let sharpened = bw.applyingFilter("CISharpenLuminance", parameters: [
            "inputSharpness": 0.7
        ]) as CIImage? else { return nil }

        guard let cgImage = context.createCGImage(sharpened, from: sharpened.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func performTextRecognition(on image: UIImage) async -> [(text: String, confidence: Float)]? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate  // Required for spine text
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02  // Lower to catch smaller spine text
        request.recognitionLanguages = ["en-US"]

        // Add common book-related words to improve recognition
        request.customWords = [
            "Tolkien", "Rowling", "Martin", "King", "Christie", "Austen",
            "Silmarillion", "Odyssey", "Hobbit", "Chronicles"
        ]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results else { return nil }

            var recognizedText: [(text: String, confidence: Float)] = []

            for observation in results {
                guard let candidate = observation.topCandidates(1).first else { continue }

                let text = candidate.string
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Filter out very short fragments and low confidence
                if text.count > 3 && candidate.confidence > 0.5 {
                    recognizedText.append((
                        text: text,
                        confidence: candidate.confidence
                    ))
                }
            }

            return recognizedText.isEmpty ? nil : recognizedText
        } catch {
            #if DEBUG
            print("❌ Text recognition error: \(error)")
            #endif
            return nil
        }
    }
}

// MARK: - DataScanner UIKit Wrapper

@available(iOS 16.0, *)
struct PerfectDataScannerRepresentable: UIViewControllerRepresentable {
    let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    let recognizesMultipleItems: Bool
    let isHighFrameRateTrackingEnabled: Bool
    let isHighlightingEnabled: Bool
    let qualityLevel: DataScannerViewController.QualityLevel
    let onScannedItems: ([RecognizedItem]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: qualityLevel,
            recognizesMultipleItems: recognizesMultipleItems,
            isHighFrameRateTrackingEnabled: isHighFrameRateTrackingEnabled,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: isHighlightingEnabled
        )

        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Start scanning if not already
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScannedItems: onScannedItems)
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScannedItems: ([RecognizedItem]) -> Void

        init(onScannedItems: @escaping ([RecognizedItem]) -> Void) {
            self.onScannedItems = onScannedItems
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            onScannedItems([item])
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            onScannedItems(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Only process new items to avoid duplicates
            if !updatedItems.isEmpty {
                onScannedItems(updatedItems)
            }
        }
    }
}

// MARK: - UIImage Extension for Rotation

extension UIImage {
    func rotated(by degrees: CGFloat) -> UIImage? {
        let radians = degrees * .pi / 180

        var newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .size

        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage
    }
}
