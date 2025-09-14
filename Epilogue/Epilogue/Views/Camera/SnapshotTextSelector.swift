import SwiftUI
import Vision
import VisionKit
import PhotosUI

// MARK: - Snapshot Text Selector with Quick Actions
struct SnapshotTextSelector: View {
    @Binding var isPresented: Bool
    let onQuoteSaved: (String, String?) -> Void // text, page number
    let onQuestionAsked: (String) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var recognizedTextBlocks: [TextBlock] = []
    @State private var selectedText: String = ""
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var selectedRange: Range<String.Index>?
    
    struct TextBlock: Identifiable {
        let id = UUID()
        let text: String
        let bounds: CGRect
        var isSelected: Bool = false
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color.black.ignoresSafeArea()
                
                if let image = capturedImage {
                    // Show captured image with text overlay
                    imageWithTextOverlay(image)
                } else {
                    // Camera prompt
                    cameraPromptView
                }
                
                // Processing overlay
                if isProcessing {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                    
                    ProgressView("Detecting text...")
                        .foregroundStyle(.white)
                        .padding()
                        .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.white)
                }
                
                if capturedImage != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            capturedImage = nil
                            recognizedTextBlocks = []
                            selectedText = ""
                            showingCamera = true
                        } label: {
                            Image(systemName: "camera")
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { image in
                capturedImage = image
                showingCamera = false
                processImage(image)
            }
        }
        .onAppear {
            if capturedImage == nil {
                showingCamera = true
            }
        }
    }
    
    // MARK: - Camera Prompt
    private var cameraPromptView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Take a snapshot of the page")
                .font(.title2)
                .foregroundStyle(.white)
            
            Button {
                showingCamera = true
            } label: {
                Label("Open Camera", systemImage: "camera.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }
        }
    }
    
    // MARK: - Image with Text Overlay
    private func imageWithTextOverlay(_ image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Base image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Selectable text blocks overlay
                ForEach(recognizedTextBlocks) { block in
                    Rectangle()
                        .fill(block.isSelected ? Color.blue.opacity(0.3) : Color.clear)
                        .border(block.isSelected ? Color.blue : Color.clear, width: 2)
                        .frame(
                            width: block.bounds.width * geometry.size.width,
                            height: block.bounds.height * geometry.size.height
                        )
                        .position(
                            x: block.bounds.midX * geometry.size.width,
                            y: block.bounds.midY * geometry.size.height
                        )
                        .onTapGesture {
                            toggleTextSelection(block)
                        }
                }
                
                // Selected text actions overlay
                if !selectedText.isEmpty {
                    VStack {
                        Spacer()
                        selectedTextActions
                    }
                }
            }
        }
    }
    
    // MARK: - Selected Text Actions
    private var selectedTextActions: some View {
        VStack(spacing: 16) {
            // Selected text preview
            Text(selectedText)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .lineLimit(3)
                .padding()
                .frame(maxWidth: .infinity)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 16) {
                // Save as Quote button
                Button {
                    let pageNumber = extractPageNumber(from: recognizedTextBlocks)
                    onQuoteSaved(selectedText, pageNumber)
                    isPresented = false
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 24))
                        Text("Save Quote")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                }
                
                // Ask Question button
                Button {
                    onQuestionAsked(selectedText)
                    isPresented = false
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 24))
                        Text("Ask About")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Text Selection
    private func toggleTextSelection(_ block: TextBlock) {
        if let index = recognizedTextBlocks.firstIndex(where: { $0.id == block.id }) {
            recognizedTextBlocks[index].isSelected.toggle()
            
            // Update selected text
            selectedText = recognizedTextBlocks
                .filter { $0.isSelected }
                .map { $0.text }
                .joined(separator: " ")
        }
    }
    
    // MARK: - Image Processing
    private func processImage(_ image: UIImage) {
        isProcessing = true
        
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
            var blocks: [TextBlock] = []
            
            for observation in observations {
                if let text = observation.topCandidates(1).first?.string {
                    // Convert Vision coordinates to SwiftUI coordinates
                    let bounds = CGRect(
                        x: observation.boundingBox.origin.x,
                        y: 1 - observation.boundingBox.origin.y - observation.boundingBox.height,
                        width: observation.boundingBox.width,
                        height: observation.boundingBox.height
                    )
                    
                    blocks.append(TextBlock(
                        text: text,
                        bounds: bounds
                    ))
                }
            }
            
            DispatchQueue.main.async {
                self.recognizedTextBlocks = blocks
                self.isProcessing = false
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
    
    // MARK: - Page Number Extraction
    private func extractPageNumber(from blocks: [TextBlock]) -> String? {
        // Look for page numbers in the text blocks
        for block in blocks {
            // Common page number patterns
            if let match = block.text.firstMatch(of: /\b\d{1,4}\b/) {
                return String(match.output)
            }
        }
        return nil
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}