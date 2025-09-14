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
                }
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
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
                showCamera()
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
                .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
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
                showCamera()
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
    
    // MARK: - Camera Handling
    private func showCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = ImagePickerCoordinator(
            onImagePicked: { image in
                capturedImage = image
                processImage(image)
            }
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(picker, animated: true)
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

// MARK: - Image Picker Coordinator
private class ImagePickerCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onImagePicked: (UIImage) -> Void
    
    init(onImagePicked: @escaping (UIImage) -> Void) {
        self.onImagePicked = onImagePicked
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            onImagePicked(image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
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