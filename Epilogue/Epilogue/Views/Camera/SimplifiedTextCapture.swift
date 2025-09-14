import SwiftUI
import Vision
import UIKit

// MARK: - Simplified Text Capture - Lightweight & Fast
struct SimplifiedTextCapture: View {
    @Binding var isPresented: Bool
    let onTextCaptured: (String) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = capturedImage {
                    // Show captured image with extracted text
                    capturedImageView(image)
                } else {
                    // Simple camera button
                    cameraPromptView
                        .onAppear {
                            // Auto-show camera on appear
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                showingImagePicker = true
                            }
                        }
                }
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingImagePicker) {
                CameraImagePicker(image: $capturedImage) { image in
                    if let image = image {
                        processImage(image)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.white)
                }
                
                if !extractedText.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            onTextCaptured(extractedText)
                            isPresented = false
                        }
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Camera Prompt
    private var cameraPromptView: some View {
        VStack(spacing: 32) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.8))
            
            Text("Take a photo of text")
                .font(.title2)
                .foregroundStyle(.white)
            
            Button {
                showingImagePicker = true
            } label: {
                Text("Open Camera")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(.white))
            }
        }
    }
    
    // MARK: - Captured Image View
    private func capturedImageView(_ image: UIImage) -> some View {
        VStack(spacing: 0) {
            // Image at top
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 400)
                .clipped()
            
            // Extracted text below
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                        Text("Extracted Text")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        if !extractedText.isEmpty {
                            Text("\(extractedText.split(separator: " ").count) words")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if extractedText.isEmpty {
                        Text("No text found in image")
                            .foregroundStyle(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        // Editable text field
                        TextEditor(text: $extractedText)
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal)
                            .frame(minHeight: 200)
                    }
                }
            }
            .background(Color.black.opacity(0.3))
            
            // Retake button
            Button {
                capturedImage = nil
                extractedText = ""
                showingImagePicker = true
            } label: {
                HStack {
                    Image(systemName: "camera")
                    Text("Retake Photo")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .glassEffect(in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
    }
    
    // MARK: - Lightweight OCR Processing
    private func processImage(_ image: UIImage) {
        isProcessing = true
        
        // Downsample image for faster processing
        guard let downsampledImage = image.downsample(to: CGSize(width: 1024, height: 1024)),
              let cgImage = downsampledImage.cgImage else {
            isProcessing = false
            return
        }
        
        // Simple text recognition request
        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                defer { isProcessing = false }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                // Extract text efficiently
                let recognizedText = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                
                extractedText = recognizedText
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        request.recognitionLevel = .fast // Use fast recognition for better performance
        request.usesLanguageCorrection = true
        
        // Process in background
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
}

// MARK: - Camera Image Picker
struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let onImagePicked: (UIImage?) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker
        
        init(_ parent: CameraImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.onImagePicked(uiImage)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Image Extension for Downsampling
extension UIImage {
    func downsample(to targetSize: CGSize) -> UIImage? {
        let size = self.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
}