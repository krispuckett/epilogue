import SwiftUI

/// Debug overlay for visualizing color extraction results
struct ColorExtractionDebugView: View {
    let book: Book
    let coverImage: UIImage?
    
    @State private var extractedPalette: ColorPalette?
    @State private var isExtracting = false
    @State private var useHighResolution = true
    @State private var showHexValues = true
    @State private var extractionTime: TimeInterval = 0
    @State private var imageChecksum: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Original Image Section
                    originalImageSection
                    
                    // Controls
                    controlsSection
                    
                    // Extraction Info
                    if extractedPalette != nil {
                        extractionInfoSection
                    }
                    
                    // Color Swatches
                    if let palette = extractedPalette {
                        colorSwatchesSection(palette: palette)
                    }
                    
                    // Generated Gradient Preview
                    if let palette = extractedPalette {
                        gradientPreviewSection(palette: palette)
                    }
                    
                    // Debug Info
                    debugInfoSection
                }
                .padding()
            }
            .navigationTitle("Color Extraction Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await performInitialExtraction()
        }
    }
    
    // MARK: - Sections
    
    private var originalImageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Original Image")
                .font(.headline)
            
            if let coverImage = coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                    .shadow(radius: 5)
                
                HStack {
                    Text("Size: \(Int(coverImage.size.width))×\(Int(coverImage.size.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Checksum: \(imageChecksum.prefix(8))...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Text("No cover image")
                            .foregroundColor(.secondary)
                    )
            }
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 15) {
            Toggle("High Resolution Extraction", isOn: $useHighResolution)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Toggle("Show Hex Values", isOn: $showHexValues)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Button(action: {
                Task {
                    await forceReExtraction()
                }
            }) {
                Label("Force Re-extraction", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExtracting)
            
            Button(action: clearCache) {
                Label("Clear Cache", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var extractionInfoSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Extraction Info")
                .font(.headline)
            
            HStack {
                Label("Time:", systemImage: "clock")
                    .font(.caption)
                Spacer()
                Text("\(String(format: "%.2f", extractionTime))s")
                    .font(.caption.monospaced())
            }
            
            HStack {
                Label("Quality:", systemImage: "star.fill")
                    .font(.caption)
                Spacer()
                Text("\(String(format: "%.1f", (extractedPalette?.extractionQuality ?? 0) * 100))%")
                    .font(.caption.monospaced())
            }
            
            HStack {
                Label("Monochromatic:", systemImage: "circle.fill")
                    .font(.caption)
                Spacer()
                Text(extractedPalette?.isMonochromatic == true ? "Yes" : "No")
                    .font(.caption.monospaced())
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func colorSwatchesSection(palette: ColorPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Extracted Colors")
                .font(.headline)
            
            VStack(spacing: 10) {
                colorSwatch(color: palette.primary, label: "Primary", role: "Most dominant")
                colorSwatch(color: palette.secondary, label: "Secondary", role: "Second dominant")
                colorSwatch(color: palette.accent, label: "Accent", role: "Most vibrant")
                colorSwatch(color: palette.background, label: "Background", role: "For gradients")
                colorSwatch(color: palette.textColor, label: "Text", role: "Calculated contrast")
            }
        }
    }
    
    private func colorSwatch(color: Color, label: String, role: String) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 60, height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline.bold())
                
                Text(role)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if showHexValues {
                    Text(color.bookHexString)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Color details
            VStack(alignment: .trailing, spacing: 2) {
                let (h, s, b) = color.hsbComponents
                Text("H: \(Int(h * 360))°")
                    .font(.caption2)
                Text("S: \(Int(s * 100))%")
                    .font(.caption2)
                Text("B: \(Int(b * 100))%")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func gradientPreviewSection(palette: ColorPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Generated Gradient")
                .font(.headline)
            
            // Recreate the BookAtmosphericGradientView gradient
            ZStack {
                Color.black
                
                LinearGradient(
                    stops: [
                        .init(color: palette.primary, location: 0.0),
                        .init(color: palette.secondary, location: 0.2),
                        .init(color: palette.accent.opacity(0.7), location: 0.35),
                        .init(color: palette.background.opacity(0.3), location: 0.5),
                        .init(color: Color.clear, location: 0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blur(radius: 40)
            }
            .frame(height: 200)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Debug Info")
                .font(.headline)
            
            debugRow("Book ID", value: book.id ?? "N/A")
                .font(.caption)
            debugRow("ISBN", value: book.isbn ?? "N/A")
                .font(.caption)
            debugRow("Cover URL", value: book.coverImageURL ?? "N/A")
                .font(.caption)
            
            Divider()
            
            let stats = BookColorPaletteCache.shared.getCacheStats()
            debugRow("Memory Cache", value: "\(stats.memoryCacheCount) items")
                .font(.caption)
            debugRow("Disk Cache", value: "\(stats.diskCacheCount) items")
                .font(.caption)
            debugRow("Disk Size", value: String(format: "%.2f MB", stats.totalDiskSizeMB))
                .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func debugRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
    
    // MARK: - Actions
    
    private func performInitialExtraction() async {
        guard let coverImage = coverImage else { return }
        
        isExtracting = true
        let startTime = Date()
        
        // Calculate checksum
        imageChecksum = calculateChecksum(for: coverImage)
        
        do {
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(
                from: coverImage,
                imageSource: "Debug-\(book.title ?? "Unknown")"
            )
            
            extractedPalette = palette
            extractionTime = Date().timeIntervalSince(startTime)
        } catch {
            print("❌ Extraction failed: \(error)")
        }
        
        isExtracting = false
    }
    
    private func forceReExtraction() async {
        guard let coverImage = coverImage else { return }
        
        isExtracting = true
        let startTime = Date()
        
        // Resize image if needed based on resolution setting
        let imageToProcess: UIImage
        if !useHighResolution && (coverImage.size.width > 400 || coverImage.size.height > 400) {
            let scale = min(400 / coverImage.size.width, 400 / coverImage.size.height)
            let newSize = CGSize(
                width: coverImage.size.width * scale,
                height: coverImage.size.height * scale
            )
            imageToProcess = await coverImage.resized(to: newSize) ?? coverImage
        } else {
            imageToProcess = coverImage
        }
        
        do {
            let extractor = OKLABColorExtractor()
            let palette = try await extractor.extractPalette(
                from: imageToProcess,
                imageSource: "Debug-\(useHighResolution ? "HighRes" : "LowRes")-\(book.title ?? "Unknown")"
            )
            
            extractedPalette = palette
            extractionTime = Date().timeIntervalSince(startTime)
        } catch {
            print("❌ Extraction failed: \(error)")
        }
        
        isExtracting = false
    }
    
    private func clearCache() {
        Task {
            await BookColorPaletteCache.shared.clearCache()
        }
    }
    
    private func calculateChecksum(for image: UIImage) -> String {
        guard let data = image.pngData() else { return "no-data" }
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(16).uppercased()
    }
}

// MARK: - Color Extension for HSB

extension Color {
    var hsbComponents: (hue: Double, saturation: Double, brightness: Double) {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        
        return (Double(h), Double(s), Double(b))
    }
}

// MARK: - Debug Only Wrapper

#if DEBUG
struct ColorExtractionDebugGesture: ViewModifier {
    let book: Book
    let coverImage: UIImage?
    
    @State private var showDebugView = false
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 2.0) {
                showDebugView = true
            }
            .fullScreenCover(isPresented: $showDebugView) {
                ColorExtractionDebugView(book: book, coverImage: coverImage)
            }
    }
}

extension View {
    func colorExtractionDebug(book: Book, coverImage: UIImage?) -> some View {
        self.modifier(ColorExtractionDebugGesture(book: book, coverImage: coverImage))
    }
}
#endif

// Import CryptoKit for SHA256
import CryptoKit