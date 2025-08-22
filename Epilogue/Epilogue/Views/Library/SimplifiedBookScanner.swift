import SwiftUI
import AVFoundation

struct SimplifiedBookScanner: View {
    let onBookFound: (Book) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showBookSearch = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                // Simple camera preview
                SimpleCameraView()
                    .ignoresSafeArea()
                
                // UI Overlay
                VStack {
                    // Top bar
                    HStack {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundStyle(.white)
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 16) {
                        Text("Point at book cover or ISBN barcode")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .glassEffect()
                            .clipShape(Capsule())
                        
                        // Manual search button
                        Button {
                            showBookSearch = true
                        } label: {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search Manually")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .glassEffect()
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showBookSearch) {
            BookSearchSheet(
                searchQuery: "",
                onBookSelected: { book in
                    onBookFound(book)
                    showBookSearch = false
                    dismiss()
                }
            )
        }
    }
}

// Simple Camera View
struct SimpleCameraView: UIViewRepresentable {
    class CameraView: UIView {
        private var captureSession: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            setupCamera()
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupCamera()
        }
        
        private func setupCamera() {
            // Check permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.startCamera()
                    }
                }
            }
        }
        
        private func startCamera() {
            captureSession = AVCaptureSession()
            guard let captureSession = captureSession else { return }
            
            guard let camera = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: camera) else { return }
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = bounds
            
            if let previewLayer = previewLayer {
                layer.addSublayer(previewLayer)
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
    
    func makeUIView(context: Context) -> CameraView {
        return CameraView()
    }
    
    func updateUIView(_ uiView: CameraView, context: Context) {
        // No updates needed
    }
}