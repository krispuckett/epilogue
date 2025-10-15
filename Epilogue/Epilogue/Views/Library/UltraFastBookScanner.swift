import SwiftUI
import VisionKit
import AVFoundation
import Vision
import Combine

/// Ultra-fast book scanner using DataScanner API for instant ISBN detection
/// - Detects ISBN barcodes and automatically adds books
/// - Shows live text recognition overlay
/// - Minimal UI, maximum speed
@available(iOS 16.0, *)
struct UltraFastBookScanner: View {
    let onBookAdded: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = UltraFastScannerCoordinator()
    @State private var showingSearchSheet = false
    @State private var searchQuery = ""

    var body: some View {
        ZStack {
            // Full-screen camera
            DataScannerRepresentable(
                recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13])],
                recognizesMultipleItems: false,
                isHighFrameRateTrackingEnabled: true,
                isHighlightingEnabled: true,
                onScannedItems: { items in
                    handleScannedItems(items)
                }
            )
            .ignoresSafeArea()

            // Minimal UI overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .glassEffect(in: Circle())
                    }

                    Spacer()

                    // Flashlight button
                    Button {
                        scanner.toggleTorch()
                    } label: {
                        Image(systemName: scanner.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(scanner.isTorchOn ? .yellow : .white)
                            .frame(width: 44, height: 44)
                            .glassEffect(in: Circle())
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
                .padding(.top, 20)

                Spacer()

                // Status message
                if scanner.isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)

                        Text(scanner.statusMessage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
                } else {
                    Text("Point at ISBN barcode")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .glassEffect(in: Capsule())
                }

                // Manual search button
                Button {
                    showingSearchSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                        Text("Search Manually")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .glassEffect(in: Capsule())
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $showingSearchSheet) {
            BookSearchSheet(
                searchQuery: searchQuery,
                onBookSelected: { book in
                    onBookAdded(book)
                    showingSearchSheet = false
                    searchQuery = ""
                    scanner.reset()
                }
            )
        }
        .onAppear {
            scanner.onBookFound = { book in
                onBookAdded(book)
                SensoryFeedback.success()
                // Don't dismiss - allow continuous scanning
            }
        }
    }

    private func handleScannedItems(_ items: [RecognizedItem]) {
        guard !scanner.isProcessing else { return }

        for item in items {
            switch item {
            case .barcode(let barcode):
                if let payloadString = barcode.payloadStringValue {
                    // Validate ISBN
                    let cleanISBN = payloadString.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
                    if cleanISBN.count == 13 || cleanISBN.count == 10 {
                        #if DEBUG
                        print("📚 ISBN detected: \(cleanISBN)")
                        #endif
                        scanner.processISBN(cleanISBN)
                        return
                    }
                }
            default:
                break
            }
        }
    }
}

/// Coordinator for ultra-fast scanner
@MainActor
class UltraFastScannerCoordinator: ObservableObject {
    @Published var isProcessing = false
    @Published var statusMessage = "Ready"
    @Published var isTorchOn = false
    @Published var lastScannedISBN: String?

    var onBookFound: ((Book) -> Void)?

    private let booksService = EnhancedGoogleBooksService()

    func processISBN(_ isbn: String) {
        // Prevent duplicate scans
        guard lastScannedISBN != isbn else {
            #if DEBUG
            print("⚠️ Ignoring duplicate ISBN scan")
            #endif
            return
        }

        lastScannedISBN = isbn
        isProcessing = true
        statusMessage = "Looking up ISBN..."

        // Heavy haptic for detection
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        Task {
            // Search for book by ISBN
            let results = await booksService.searchBooksWithRanking(query: "isbn:\(isbn)")

            await MainActor.run {
                if let firstBook = results.first {
                    statusMessage = "Found: \(firstBook.title)"
                    #if DEBUG
                    print("✅ Auto-adding book: \(firstBook.title)")
                    #endif

                    // Success haptic
                    UINotificationFeedbackGenerator().notificationOccurred(.success)

                    // Auto-add the book
                    onBookFound?(firstBook)

                    // Reset after short delay
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
                        await MainActor.run {
                            reset()
                        }
                    }
                } else {
                    statusMessage = "Book not found"
                    #if DEBUG
                    print("❌ No book found for ISBN: \(isbn)")
                    #endif

                    // Error haptic
                    UINotificationFeedbackGenerator().notificationOccurred(.error)

                    // Reset faster
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                        await MainActor.run {
                            reset()
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
        statusMessage = "Ready"
        lastScannedISBN = nil
    }
}

/// SwiftUI wrapper for DataScannerViewController
@available(iOS 16.0, *)
struct DataScannerRepresentable: UIViewControllerRepresentable {
    let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    let recognizesMultipleItems: Bool
    let isHighFrameRateTrackingEnabled: Bool
    let isHighlightingEnabled: Bool
    let onScannedItems: ([RecognizedItem]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
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

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }
}
