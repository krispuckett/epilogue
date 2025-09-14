import SwiftUI
import VisionKit
import UIKit

// MARK: - Enhanced Text Scanner with Better Selection
struct EnhancedTextScannerView: View {
    @Binding var isPresented: Bool
    let onTextSelected: (String, SelectionMode) -> Void
    
    enum SelectionMode {
        case quote
        case question
    }
    
    @State private var selectedText: String = ""
    @State private var selectionMode: SelectionMode = .quote
    @State private var isSelecting = false
    @State private var recognizedTexts: [EnhancedDataScannerView.RecognizedText] = []
    @State private var selectedTextBounds: CGRect = .zero
    
    var body: some View {
        ZStack {
            // Live Text Scanner with enhanced controls
            EnhancedDataScannerView(
                selectedText: $selectedText,
                isPresented: $isPresented,
                isSelecting: $isSelecting,
                recognizedTexts: $recognizedTexts,
                selectedTextBounds: $selectedTextBounds
            )
            .ignoresSafeArea()
            
            // Enhanced UI Overlay
            VStack {
                // Top control bar
                topControlBar
                
                Spacer()
                
                // Selection mode switcher
                if !selectedText.isEmpty {
                    selectionModeView
                }
                
                // Bottom control panel
                bottomControlPanel
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Top Control Bar
    private var topControlBar: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
            .padding()
            
            Spacer()
            
            // Selection indicator
            if isSelecting {
                HStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 14))
                    Text("Selecting...")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.yellow)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.yellow.opacity(0.2)))
                .overlay(Capsule().stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                .padding(.trailing)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .ignoresSafeArea()
        )
    }
    
    // MARK: - Selection Mode View
    private var selectionModeView: some View {
        HStack(spacing: 12) {
            ForEach([SelectionMode.quote, .question], id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectionMode = mode
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: mode == .quote ? "quote.bubble" : "questionmark.circle")
                        Text(mode == .quote ? "Save as Quote" : "Ask Question")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(selectionMode == mode ? .black : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selectionMode == mode ? Color.white : Color.white.opacity(0.2))
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Bottom Control Panel
    private var bottomControlPanel: some View {
        VStack(spacing: 16) {
            // Instructions or selected text
            if selectedText.isEmpty {
                instructionsView
            } else {
                selectedTextPreview
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if !selectedText.isEmpty {
                    // Clear selection
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedText = ""
                            isSelecting = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(Circle().fill(Color.red.opacity(0.3)))
                            .overlay(Circle().stroke(Color.red.opacity(0.5), lineWidth: 1))
                    }
                    
                    Spacer()
                    
                    // Confirm selection
                    Button {
                        onTextSelected(selectedText, selectionMode)
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: selectionMode == .quote ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 20))
                            Text(selectionMode == .quote ? "Save Quote" : "Ask About This")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .frame(height: 50)
                        .background(Capsule().fill(Color.white))
                    }
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 32)
    }
    
    // MARK: - Instructions View
    private var instructionsView: some View {
        VStack(spacing: 12) {
            // Visual guide
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 24))
                    Text("Tap")
                        .font(.system(size: 11, weight: .medium))
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
                
                VStack(spacing: 4) {
                    Image(systemName: "text.cursor")
                        .font(.system(size: 24))
                    Text("Select")
                        .font(.system(size: 11, weight: .medium))
                }
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
                
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                    Text("Save")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Text("Point camera at text and tap to select")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Selected Text Preview
    private var selectedTextPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: selectionMode == .quote ? "quote.bubble.fill" : "questionmark.circle.fill")
                    .foregroundColor(selectionMode == .quote ? .blue : .green)
                Text(selectionMode == .quote ? "Selected Quote" : "Text to Ask About")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(selectedText.split(separator: " ").count) words")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            ScrollView {
                Text(selectedText)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 80)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill((selectionMode == .quote ? Color.blue : Color.green).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke((selectionMode == .quote ? Color.blue : Color.green).opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Enhanced Data Scanner View
struct EnhancedDataScannerView: UIViewControllerRepresentable {
    @Binding var selectedText: String
    @Binding var isPresented: Bool
    @Binding var isSelecting: Bool
    @Binding var recognizedTexts: [RecognizedText]
    @Binding var selectedTextBounds: CGRect
    
    struct RecognizedText: Identifiable {
        let id = UUID()
        let text: String
        let bounds: CGRect
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let hostingController = UIViewController()
        
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,  // Allow multiple text blocks
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        scanner.delegate = context.coordinator
        
        // Add scanner as child
        hostingController.addChild(scanner)
        hostingController.view.addSubview(scanner.view)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scanner.view.leadingAnchor.constraint(equalTo: hostingController.view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: hostingController.view.trailingAnchor),
            scanner.view.topAnchor.constraint(equalTo: hostingController.view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: hostingController.view.bottomAnchor)
        ])
        scanner.didMove(toParent: hostingController)
        
        // Store scanner reference
        context.coordinator.scanner = scanner
        
        return hostingController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let scanner = context.coordinator.scanner {
            if isPresented {
                try? scanner.startScanning()
            } else {
                scanner.stopScanning()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: EnhancedDataScannerView
        var scanner: DataScannerViewController?
        
        init(_ parent: EnhancedDataScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                DispatchQueue.main.async {
                    // Add to selection or replace
                    if self.parent.isSelecting && !self.parent.selectedText.isEmpty {
                        // Append to existing selection
                        self.parent.selectedText += " " + text.transcript
                    } else {
                        // New selection
                        self.parent.selectedText = text.transcript
                        self.parent.isSelecting = true
                    }
                    
                    // Haptic feedback
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                }
            default:
                break
            }
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // Update recognized texts for visual feedback
            DispatchQueue.main.async {
                self.parent.recognizedTexts = allItems.compactMap { item in
                    switch item {
                    case .text(let text):
                        return RecognizedText(
                            text: text.transcript,
                            bounds: .zero  // Would need to calculate actual bounds
                        )
                    default:
                        return nil
                    }
                }
            }
        }
    }
}