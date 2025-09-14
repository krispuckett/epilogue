import SwiftUI
import PhotosUI
import Vision
import VisionKit

// MARK: - Quick Text Capture with Better OCR
struct QuickTextCapture: View {
    @Binding var isPresented: Bool
    let onTextCaptured: (String) -> Void
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var showCamera = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top section - Image or placeholder
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .clipped()
                        .overlay(alignment: .topTrailing) {
                            Button {
                                selectedImage = nil
                                extractedText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .background(Circle().fill(.black.opacity(0.5)))
                            }
                            .padding()
                        }
                } else {
                    imageSelectionView
                }
                
                // Text editor section
                if !extractedText.isEmpty || selectedImage != nil {
                    textEditorSection
                }
                
                Spacer()
            }
            .navigationTitle("Capture Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !extractedText.isEmpty {
                        Button("Done") {
                            onTextCaptured(extractedText)
                            isPresented = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Extracting text...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
                }
            }
        }
        .interactiveDismissDisabled()
        .photosPicker(isPresented: $showCamera, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                await loadPhoto(newValue)
            }
        }
    }
    
    // MARK: - Image Selection View
    private var imageSelectionView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "text.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("Select a photo with text")
                .font(.title2)
            
            HStack(spacing: 16) {
                // Camera button
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Photo library button
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Photos", systemImage: "photo.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
    }
    
    // MARK: - Text Editor Section
    private var textEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Extracted Text", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                if !extractedText.isEmpty {
                    Text("\(extractedText.split(separator: " ").count) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if extractedText.isEmpty && selectedImage != nil {
                Text("No text found in image")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                TextEditor(text: $extractedText)
                    .font(.body)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .frame(minHeight: 150)
            }
            
            // Quick actions
            if !extractedText.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = extractedText
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        extractedText = ""
                    } label: {
                        Label("Clear", systemImage: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Photo Loading
    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isProcessing = true
        
        // Load image data
        if let data = try? await item.loadTransferable(type: Data.self),
           let uiImage = UIImage(data: data) {
            
            await MainActor.run {
                selectedImage = uiImage
            }
            
            // Process with better OCR
            await processImageWithVision(uiImage)
        }
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    // MARK: - Improved Vision OCR
    private func processImageWithVision(_ image: UIImage) async {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            // Sort observations by their position (top to bottom, left to right)
            let sortedObservations = observations.sorted { first, second in
                // Compare Y position first (top to bottom)
                let firstY = 1.0 - first.boundingBox.origin.y - first.boundingBox.height
                let secondY = 1.0 - second.boundingBox.origin.y - second.boundingBox.height
                
                if abs(firstY - secondY) > 0.02 { // If on different lines
                    return firstY < secondY
                } else { // If on same line, sort by X position
                    return first.boundingBox.origin.x < second.boundingBox.origin.x
                }
            }
            
            // Build text with proper spacing
            var recognizedText = ""
            var lastY: CGFloat = 0
            
            for observation in sortedObservations {
                let currentY = 1.0 - observation.boundingBox.origin.y - observation.boundingBox.height
                
                // Add line break if Y position changed significantly
                if !recognizedText.isEmpty && abs(currentY - lastY) > 0.02 {
                    recognizedText += "\n"
                } else if !recognizedText.isEmpty {
                    recognizedText += " "
                }
                
                if let text = observation.topCandidates(1).first?.string {
                    recognizedText += text
                }
                
                lastY = currentY
            }
            
            Task { @MainActor in
                self.extractedText = recognizedText
            }
        }
        
        // Use accurate recognition for better results
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? requestHandler.perform([request])
    }
}