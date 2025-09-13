import SwiftUI
import VisionKit
import UIKit

// MARK: - Live Text Scanner View for Quote Selection
struct DataScannerView: UIViewControllerRepresentable {
    @Binding var scannedText: String
    @Binding var isPresented: Bool
    let onTextSelected: (String) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        // Start scanning when view appears
        if isPresented {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: DataScannerView
        
        init(_ parent: DataScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                switch item {
                case .text(let text):
                    // User selected specific text
                    DispatchQueue.main.async {
                        self.parent.scannedText = text.transcript
                        self.parent.onTextSelected(text.transcript)
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                default:
                    break
                }
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Handle updates if needed
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Handle removal if needed
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            // Handle tap on recognized text
            switch item {
            case .text(let text):
                DispatchQueue.main.async {
                    self.parent.scannedText = text.transcript
                    self.parent.onTextSelected(text.transcript)
                    
                    // Strong haptic for selection
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    // Auto-dismiss after selection
                    self.parent.isPresented = false
                }
            default:
                break
            }
        }
    }
}

// MARK: - Live Text Scanner Container View
struct LiveTextScannerView: View {
    @Binding var isPresented: Bool
    @Binding var scannedText: String
    let onQuoteCaptured: (String) -> Void
    
    @State private var selectedText: String = ""
    @State private var showInstructions = true
    
    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                // Live Text Scanner
                DataScannerView(
                    scannedText: $selectedText,
                    isPresented: $isPresented,
                    onTextSelected: { text in
                        selectedText = text
                        showInstructions = false
                    }
                )
                .ignoresSafeArea()
                
                // Overlay UI
                VStack {
                    // Top bar
                    HStack {
                        Button("Cancel") {
                            isPresented = false
                        }
                        .foregroundColor(.white)
                        .padding()
                        
                        Spacer()
                        
                        if !selectedText.isEmpty {
                            Button("Save Quote") {
                                onQuoteCaptured(selectedText)
                                isPresented = false
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                            .padding()
                        }
                    }
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.7), Color.clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()
                    
                    // Bottom instructions or selected text preview
                    VStack(spacing: 12) {
                        if showInstructions {
                            // Instructions
                            VStack(spacing: 8) {
                                Image(systemName: "text.viewfinder")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                
                                Text("Tap on text to select it")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Position the text in view and tap to capture")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.black.opacity(0.7))
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 32)
                        } else if !selectedText.isEmpty {
                            // Selected text preview
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "quote.bubble.fill")
                                        .foregroundColor(.blue)
                                    Text("Selected Quote")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(selectedText.split(separator: " ").count) words")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Text(selectedText)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .lineLimit(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 32)
                }
            } else {
                // Fallback for devices that don't support Live Text
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Live Text not available")
                        .font(.headline)
                    
                    Text("This device doesn't support Live Text selection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Use Regular Camera") {
                        isPresented = false
                        // Fallback to regular image picker
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
    }
}