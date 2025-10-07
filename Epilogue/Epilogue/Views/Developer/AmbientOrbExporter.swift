import SwiftUI

/// Tool to capture high-res static image of AmbientOrbButton for widget use
/// Access from Settings > Developer Options
struct AmbientOrbExporter: View {
    @State private var showCaptureButton = true
    @State private var capturedImage: UIImage?
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Ambient Orb Export")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Render the orb at high resolution for widget assets")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // High-res orb render (300x300 for @3x assets)
                ZStack {
                    if showCaptureButton {
                        AmbientOrbButton(size: 300) {}
                            .disabled(true)
                    }

                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 300, height: 300)
                    }
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        captureOrb()
                    } label: {
                        Text("Capture Orb Image")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DesignSystem.Colors.primaryAccent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)

                    if capturedImage != nil {
                        Button {
                            showShareSheet = true
                        } label: {
                            Text("Save to Files")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }

                    Text("Instructions:\n1. Tap 'Capture Orb Image'\n2. Save the image to Files\n3. Add to Widget extension Assets catalog as 'ambient-orb'")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = capturedImage {
                ShareSheet(items: [image])
            }
        }
    }

    private func captureOrb() {
        // Create a hosting controller with the orb
        let orbView = AmbientOrbButton(size: 300) {}
            .disabled(true)
            .background(Color.clear)

        let controller = UIHostingController(rootView: orbView)
        controller.view.backgroundColor = .clear
        controller.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)

        // Wait a moment for Metal to render
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
            let image = renderer.image { context in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }

            capturedImage = image
            showCaptureButton = false
            SensoryFeedback.success()
        }
    }
}

// Share Sheet for saving image
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AmbientOrbExporter()
}
