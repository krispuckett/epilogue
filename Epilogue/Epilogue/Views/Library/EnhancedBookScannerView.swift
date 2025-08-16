import SwiftUI
import AVKit
import Vision

struct EnhancedBookScannerView: View {
    let onBookFound: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var bookScanner = BookScannerService.shared
    @State private var isProcessing = false
    @State private var detectionStatus = "Position book cover or ISBN barcode"
    @State private var lastScannedISBN: String?
    @State private var showBookSearch = false
    @State private var searchQuery = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background for camera
                Color.black
                    .ignoresSafeArea()
                
                // Unified camera view that detects both
                CameraScannerView(
                    onBookFound: onBookFound,
                    isProcessing: $isProcessing,
                    detectionStatus: $detectionStatus
                )
                .ignoresSafeArea()
                
                // Top gradient overlay for depth (like ambient mode)
                VStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.4),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 200)
                    .ignoresSafeArea()
                    
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // Overlay UI
                VStack {
                    Spacer()
                    
                    // Scanning guidance overlay
                    VStack(spacing: 20) {
                        // Visual scanning frame - Simple and clean
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 3)
                            .frame(width: 280, height: 380)
                            .overlay(
                                // Corner markers
                                Group {
                                    // Top left
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 30))
                                        path.addLine(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 0))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 15, y: 15)
                                    
                                    // Top right
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 30))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 265, y: 15)
                                    
                                    // Bottom left
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 0, y: 30))
                                        path.addLine(to: CGPoint(x: 30, y: 30))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 15, y: 365)
                                    
                                    // Bottom right
                                    Path { path in
                                        path.move(to: CGPoint(x: 30, y: 0))
                                        path.addLine(to: CGPoint(x: 30, y: 30))
                                        path.addLine(to: CGPoint(x: 0, y: 30))
                                    }
                                    .stroke(Color(red: 1.0, green: 0.55, blue: 0.26), lineWidth: 4)
                                    .frame(width: 30, height: 30)
                                    .position(x: 265, y: 365)
                                }
                            )
                        
                        // Status text
                        Text(detectionStatus)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .glassEffect()
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Cancel button at bottom
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .glassEffect()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                
                if isProcessing {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Identifying book...")
                            .foregroundStyle(.white)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: searchQuery,
                onBookSelected: { book in
                    onBookFound(book)
                    showBookSearch = false
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $bookScanner.showSearchResults) {
            BookSearchSheet(
                searchQuery: bookScanner.extractedText,
                onBookSelected: { book in
                    onBookFound(book)
                    bookScanner.reset()
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Camera Scanner View
struct CameraScannerView: UIViewControllerRepresentable {
    let onBookFound: (Book) -> Void
    @Binding var isProcessing: Bool
    @Binding var detectionStatus: String
    
    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let controller = CameraScannerViewController()
        controller.onBookFound = onBookFound
        controller.isProcessing = $isProcessing
        controller.detectionStatus = $detectionStatus
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Camera Scanner View Controller
class CameraScannerViewController: UIViewController {
    var onBookFound: ((Book) -> Void)?
    var isProcessing: Binding<Bool>?
    var detectionStatus: Binding<String>?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var lastProcessedTime = Date()
    private var processingISBN = false
    private var rectangleDetectionTimer: Timer?
    private var consecutiveDetections = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession,
              let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        // Add metadata output for barcode scanning
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            // For ISBN barcode scanning
            if metadataOutput.availableMetadataObjectTypes.contains(.ean13) {
                metadataOutput.metadataObjectTypes = [.ean13, .ean8]
            }
        }
        
        // Add photo output for visual book scanning
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Add video output for rectangle detection
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
}

// MARK: - Video Data Delegate for Rectangle Detection
extension CameraScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle detection to avoid excessive processing
        guard Date().timeIntervalSince(lastProcessedTime) > 0.5,
              !processingISBN,
              isProcessing?.wrappedValue == false else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Detect rectangles for book covers
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNRectangleObservation],
                  let rect = results.first,
                  rect.confidence > 0.8 else {
                DispatchQueue.main.async {
                    self?.consecutiveDetections = 0
                }
                return
            }
            
            // Book cover detected with high confidence
            DispatchQueue.main.async {
                self?.consecutiveDetections += 1
                self?.detectionStatus?.wrappedValue = "Book cover detected - hold steady"
                
                // After 3 consecutive detections, capture the photo
                if self?.consecutiveDetections ?? 0 >= 3 {
                    self?.captureBookPhoto()
                }
            }
        }
        
        request.minimumConfidence = 0.7
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
        
        lastProcessedTime = Date()
    }
    
    private func captureBookPhoto() {
        guard let photoOutput = photoOutput,
              isProcessing?.wrappedValue == false else { return }
        
        isProcessing?.wrappedValue = true
        captureSession?.stopRunning()
        detectionStatus?.wrappedValue = "Processing book cover..."
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate
extension CameraScannerViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            // Photo capture failed
            DispatchQueue.main.async { [weak self] in
                self?.isProcessing?.wrappedValue = false
                self?.captureSession?.startRunning()
                self?.detectionStatus?.wrappedValue = "Capture failed. Try again."
            }
            return
        }
        
        // Process the captured image with BookScannerService
        Task {
            let scanner = BookScannerService.shared
            let bookInfo = await scanner.processScannedImage(image)
            
            if bookInfo.hasValidInfo {
                // Search for the book
                await scanner.searchWithExtractedInfo(bookInfo)
                
                // Wait a moment for search to complete
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Show the search results sheet
                await MainActor.run { [weak self] in
                    // The BookScannerService will set showSearchResults to true
                    // which triggers the sheet in ContentView
                    self?.isProcessing?.wrappedValue = false
                    
                    // Dismiss the scanner to show the search sheet
                    if let parent = self?.parent as? UIViewController {
                        parent.dismiss(animated: true)
                    }
                }
            } else {
                await MainActor.run { [weak self] in
                    self?.isProcessing?.wrappedValue = false
                    self?.captureSession?.startRunning()
                    self?.detectionStatus?.wrappedValue = "Could not read book cover. Try ISBN."
                    self?.consecutiveDetections = 0
                }
            }
        }
    }
}

// MARK: - Metadata Delegate for Barcode Scanning
extension CameraScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    private func findParentViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Don't process if already processing or too soon after last scan
        guard !processingISBN,
              Date().timeIntervalSince(lastProcessedTime) > 2,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        
        // Update status
        DispatchQueue.main.async { [weak self] in
            self?.detectionStatus?.wrappedValue = "ISBN detected: \(stringValue)"
        }
        
        // Found ISBN barcode
        processingISBN = true
        lastProcessedTime = Date()
        isProcessing?.wrappedValue = true
        captureSession?.stopRunning()
        
        // Search for book by ISBN using Google Books API
        Task {
            let googleBooks = GoogleBooksService()
            if let book = await googleBooks.searchBookByISBN(stringValue) {
                // Found book - call the callback
                await MainActor.run { [weak self] in
                    self?.onBookFound?(book)
                    self?.processingISBN = false
                }
            } else {
                // ISBN not found, show search sheet with ISBN prepopulated
                await MainActor.run { [weak self] in
                    // Post notification to show book search with ISBN
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowBookSearch"),
                        object: "isbn:\(stringValue)"
                    )
                    self?.processingISBN = false
                    
                    // Dismiss the scanner since we're showing search
                    if let parent = self?.parent as? UIViewController {
                        parent.dismiss(animated: true)
                    }
                }
            }
        }
    }
}