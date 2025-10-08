import SwiftUI
import MetalKit

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
                        print("🔵 Button tapped!")
                        SensoryFeedback.selection()
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
        print("🎨 Starting Metal shader capture...")

        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal device not available")
            return
        }

        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ Failed to create command queue")
            return
        }

        // Create CPU-readable texture (NOT framebufferOnly)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: 300,
            height: 300,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        textureDescriptor.storageMode = .shared // Allow CPU access

        guard let renderTexture = device.makeTexture(descriptor: textureDescriptor) else {
            print("❌ Failed to create render texture")
            return
        }

        // Create renderer
        let renderer = OrbMetalRenderer()
        renderer.viewSizeChanged(to: CGSize(width: 300, height: 300))

        // Render a few frames to let the shader stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Render the shader directly to our texture
            renderer.renderToTexture(renderTexture, commandQueue: commandQueue, size: CGSize(width: 300, height: 300))
            print("✅ Rendered to texture")

            // Now read back the texture
            let bytesPerRow = 4 * renderTexture.width
            let region = MTLRegionMake2D(0, 0, renderTexture.width, renderTexture.height)
            let buffer = UnsafeMutableRawPointer.allocate(
                byteCount: bytesPerRow * renderTexture.height,
                alignment: MemoryLayout<UInt8>.alignment
            )
            defer { buffer.deallocate() }

            // Copy texture to buffer
            renderTexture.getBytes(
                buffer,
                bytesPerRow: bytesPerRow,
                from: region,
                mipmapLevel: 0
            )

            print("✅ Copied texture to buffer")

            // Create CGImage from buffer - Metal uses BGRA premultiplied
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            // Metal texture is in BGRA format with premultiplied alpha
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little)

            if let context = CGContext(
                data: buffer,
                width: renderTexture.width,
                height: renderTexture.height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ),
               let cgImage = context.makeImage() {

                // Debug: Check alpha values in corners (should be 0)
                let pixelData = buffer.assumingMemoryBound(to: UInt8.self)
                let topLeftAlpha = pixelData[3] // BGRA format, alpha is 4th byte
                let topRightAlpha = pixelData[(renderTexture.width - 1) * 4 + 3]
                let centerAlpha = pixelData[((renderTexture.width * (renderTexture.height / 2)) + renderTexture.width / 2) * 4 + 3]

                print("✅ Metal shader captured successfully!")
                print("   Alpha info: \(cgImage.alphaInfo.rawValue)")
                print("   Top-left corner alpha: \(topLeftAlpha)/255")
                print("   Top-right corner alpha: \(topRightAlpha)/255")
                print("   Center alpha: \(centerAlpha)/255")

                // Post-process: Threshold alpha to remove faint bloom/glow
                let processedImage = self.thresholdAlpha(UIImage(cgImage: cgImage), threshold: 0.15)

                self.capturedImage = processedImage
                self.showCaptureButton = false
                SensoryFeedback.success()
            } else {
                print("❌ Failed to create CGImage from Metal texture")
            }
        }
    }

    private func thresholdAlpha(_ image: UIImage, threshold: CGFloat) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Create pixel buffer
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return image
        }

        // Draw original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get pixel data
        guard let pixelData = context.data else { return image }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Threshold alpha
        let alphaThreshold = UInt8(threshold * 255.0)
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            let alpha = pixels[i + 3]
            if alpha < alphaThreshold {
                // Set pixel to fully transparent
                pixels[i] = 0     // B
                pixels[i + 1] = 0 // G
                pixels[i + 2] = 0 // R
                pixels[i + 3] = 0 // A
            }
        }

        // Create new image
        if let processedCGImage = context.makeImage() {
            return UIImage(cgImage: processedCGImage)
        }

        return image
    }
}

// Share Sheet for saving image as PNG with transparency
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Convert UIImage to PNG data to preserve transparency
        var itemsToShare: [Any] = []
        for item in items {
            if let image = item as? UIImage,
               let pngData = image.pngData() {
                // Create temporary PNG file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("ambient-orb.png")
                try? pngData.write(to: tempURL)
                itemsToShare.append(tempURL)
            } else {
                itemsToShare.append(item)
            }
        }

        return UIActivityViewController(activityItems: itemsToShare, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AmbientOrbExporter()
}
