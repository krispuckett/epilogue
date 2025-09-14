import SwiftUI
import VisionKit
import Vision

// MARK: - REAL Visual Intelligence Implementation
struct RealVisualIntelligenceView: View {
    @Binding var isPresented: Bool
    let onTextCaptured: (String) -> Void
    
    @State private var scannerAvailable = DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    
    var body: some View {
        if scannerAvailable {
            VisualIntelligenceScannerView(
                isPresented: $isPresented,
                onTextCaptured: onTextCaptured
            )
        } else {
            Text("Visual Intelligence not available")
                .onAppear {
                    isPresented = false
                }
        }
    }
}

// MARK: - Visual Intelligence Scanner Implementation
struct VisualIntelligenceScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onTextCaptured: (String) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isPresented {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: VisualIntelligenceScannerView
        private var capturedTexts: [String] = []
        
        init(parent: VisualIntelligenceScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                // Capture the tapped text
                parent.onTextCaptured(text.transcript)
                parent.isPresented = false
            default:
                break
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Track all recognized text
            for item in addedItems {
                if case .text(let text) = item {
                    capturedTexts.append(text.transcript)
                }
            }
        }
    }
}