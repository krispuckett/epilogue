import SwiftUI
import UIKit
import Photos
import CoreImage

@MainActor
public class ColorExtractionDiagnostic {
    
    public init() {}
    
    /// Run comprehensive diagnostic on an image
    public func runDiagnostic(on image: UIImage, bookTitle: String) async {
        print("\n🔬 COLOR EXTRACTION DIAGNOSTIC")
        print("📖 Book: \(bookTitle)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 1. Image Properties
        await analyzeImageProperties(image)
        
        // 2. Sample Random Pixels
        await sampleRandomPixels(from: image)
        
        // 3. Create Visual Debug Grid
        if let diagnosticImage = await createDiagnosticGrid(for: image, title: bookTitle) {
            await saveDiagnosticImage(diagnosticImage, title: bookTitle)
        }
        
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    // MARK: - Image Properties Analysis
    
    private func analyzeImageProperties(_ image: UIImage) async {
        print("\n📊 IMAGE PROPERTIES:")
        print("  Size: \(image.size.width) × \(image.size.height)")
        print("  Scale: \(image.scale)")
        
        guard let cgImage = image.cgImage else {
            print("  ❌ No CGImage available")
            return
        }
        
        print("  Bits per component: \(cgImage.bitsPerComponent)")
        print("  Bits per pixel: \(cgImage.bitsPerPixel)")
        print("  Bytes per row: \(cgImage.bytesPerRow)")
        print("  Alpha info: \(alphaInfoString(cgImage.alphaInfo))")
        print("  Bitmap info: \(bitmapInfoString(cgImage.bitmapInfo))")
        
        if let colorSpace = cgImage.colorSpace {
            print("\n🎨 COLOR SPACE:")
            print("  Name: \((colorSpace.name as String?) ?? "Unknown")")
            print("  Model: \(colorModelString(colorSpace.model))")
            print("  Is wide gamut: \(colorSpace.isWideGamutRGB)")
            print("  Supports output: \(colorSpace.supportsOutput)")
            
            // Check if it's Display P3
            if let cfName = colorSpace.name {
                let name = cfName as String
                if name.contains("P3") || name.contains("Display") {
                    print("  ⚠️ Display P3 detected - needs special handling!")
                }
            }
        }
    }
    
    // MARK: - Pixel Sampling
    
    private func sampleRandomPixels(from image: UIImage) async {
        print("\n🔍 SAMPLING 100 RANDOM PIXELS:")
        
        guard let cgImage = image.cgImage else { return }
        
        // Create both sRGB and Display P3 contexts
        let srgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let displayP3ColorSpace = CGColorSpace(name: CGColorSpace.displayP3)!
        
        // Sample in original color space
        if let pixelData = cgImage.dataProvider?.data,
           let data = CFDataGetBytePtr(pixelData) {
            
            let width = cgImage.width
            let height = cgImage.height
            let bytesPerPixel = cgImage.bitsPerPixel / 8
            let bytesPerRow = cgImage.bytesPerRow
            
            // Sample 100 random pixels
            var colorCounts: [String: Int] = [:]
            
            for i in 0..<100 {
                let x = Int.random(in: 0..<width)
                let y = Int.random(in: 0..<height)
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                guard offset + 2 < CFDataGetLength(pixelData) else { continue }
                
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                
                if i < 10 {  // Print first 10 samples
                    print("  Pixel \(i+1) at (\(x),\(y)):")
                    print("    Raw: R=\(r) G=\(g) B=\(b)")
                    
                    // Convert to normalized values
                    let rf = CGFloat(r) / 255.0
                    let gf = CGFloat(g) / 255.0
                    let bf = CGFloat(b) / 255.0
                    
                    // Apply gamma correction
                    let linearR = srgbToLinear(rf)
                    let linearG = srgbToLinear(gf)
                    let linearB = srgbToLinear(bf)
                    
                    print("    Normalized: R=\(String(format: "%.3f", rf)) G=\(String(format: "%.3f", gf)) B=\(String(format: "%.3f", bf))")
                    print("    Linear RGB: R=\(String(format: "%.3f", linearR)) G=\(String(format: "%.3f", linearG)) B=\(String(format: "%.3f", linearB))")
                    
                    // Check what happens in our color extraction
                    if rf > 0.95 && gf > 0.95 && bf > 0.95 {
                        print("    ⚠️ Would be SKIPPED (near white)")
                    } else if rf < 0.05 && gf < 0.05 && bf < 0.05 {
                        print("    ⚠️ Would be SKIPPED (near black)")
                    } else {
                        let quantizedR = round(rf * 10) / 10
                        let quantizedG = round(gf * 10) / 10
                        let quantizedB = round(bf * 10) / 10
                        print("    ✅ Quantized as: R=\(quantizedR) G=\(quantizedG) B=\(quantizedB)")
                    }
                }
                
                // Count color occurrences
                let colorKey = "R\(r)G\(g)B\(b)"
                colorCounts[colorKey, default: 0] += 1
            }
            
            // Print color distribution
            print("\n📊 COLOR DISTRIBUTION:")
            let sortedColors = colorCounts.sorted { $0.value > $1.value }
            for (index, (colorKey, count)) in sortedColors.prefix(5).enumerated() {
                print("  Top \(index + 1): \(colorKey) - \(count) occurrences")
            }
        }
    }
    
    // MARK: - Visual Diagnostic Grid
    
    private func createDiagnosticGrid(for image: UIImage, title: String) async -> UIImage? {
        let gridSize = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: gridSize)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Background
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: gridSize))
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.white
            ]
            let titleString = "Color Diagnostic: \(title)"
            titleString.draw(at: CGPoint(x: 20, y: 20), withAttributes: titleAttributes)
            
            // Grid layout (2x2)
            let cellSize = CGSize(width: 380, height: 250)
            let padding: CGFloat = 20
            let startY: CGFloat = 70
            
            // 1. Original Image (top-left)
            drawCell(ctx: ctx, 
                    origin: CGPoint(x: padding, y: startY),
                    size: cellSize,
                    title: "Original",
                    image: image)
            
            // 2. Gamma Corrected (top-right)
            if let gammaCorrected = applyGammaCorrection(to: image) {
                drawCell(ctx: ctx,
                        origin: CGPoint(x: padding * 2 + cellSize.width, y: startY),
                        size: cellSize,
                        title: "Gamma 2.2 Applied",
                        image: gammaCorrected)
            }
            
            // 3. sRGB Converted (bottom-left)
            if let srgbConverted = convertToSRGB(image) {
                drawCell(ctx: ctx,
                        origin: CGPoint(x: padding, y: startY + cellSize.height + padding),
                        size: cellSize,
                        title: "Forced to sRGB",
                        image: srgbConverted)
            }
            
            // 4. Color Histogram (bottom-right)
            drawHistogram(ctx: ctx,
                         origin: CGPoint(x: padding * 2 + cellSize.width, y: startY + cellSize.height + padding),
                         size: cellSize,
                         image: image)
        }
    }
    
    private func drawCell(ctx: CGContext, origin: CGPoint, size: CGSize, title: String, image: UIImage) {
        // Border
        ctx.setStrokeColor(UIColor.gray.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(origin: origin, size: size))
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.white
        ]
        title.draw(at: CGPoint(x: origin.x + 5, y: origin.y + 5), withAttributes: titleAttributes)
        
        // Image
        let imageRect = CGRect(x: origin.x + 10, 
                              y: origin.y + 30,
                              width: size.width - 20,
                              height: size.height - 40)
        image.draw(in: imageRect)
    }
    
    private func drawHistogram(ctx: CGContext, origin: CGPoint, size: CGSize, image: UIImage) {
        // Border
        ctx.setStrokeColor(UIColor.gray.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(CGRect(origin: origin, size: size))
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.white
        ]
        "Color Histogram".draw(at: CGPoint(x: origin.x + 5, y: origin.y + 5), withAttributes: titleAttributes)
        
        // Calculate histogram
        guard let histogram = calculateHistogram(for: image) else { return }
        
        // Draw bars
        let barWidth = (size.width - 40) / CGFloat(histogram.count)
        let maxCount = histogram.values.max() ?? 1
        let graphHeight = size.height - 60
        let graphOrigin = CGPoint(x: origin.x + 20, y: origin.y + size.height - 20)
        
        for (index, (color, count)) in histogram.sorted(by: { $0.value > $1.value }).prefix(20).enumerated() {
            let barHeight = CGFloat(count) / CGFloat(maxCount) * graphHeight
            let barX = graphOrigin.x + CGFloat(index) * barWidth
            let barY = graphOrigin.y - barHeight
            
            ctx.setFillColor(color.cgColor)
            ctx.fill(CGRect(x: barX, y: barY, width: barWidth - 2, height: barHeight))
        }
        
        // Axis
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.move(to: graphOrigin)
        ctx.addLine(to: CGPoint(x: graphOrigin.x + size.width - 40, y: graphOrigin.y))
        ctx.move(to: graphOrigin)
        ctx.addLine(to: CGPoint(x: graphOrigin.x, y: origin.y + 30))
        ctx.strokePath()
    }
    
    // MARK: - Image Processing
    
    private func applyGammaCorrection(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let gamma: CGFloat = 2.2
        guard let filter = CIFilter(name: "CIGammaAdjust") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(gamma, forKey: "inputPower")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    private func convertToSRGB(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let srgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: srgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let newCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage)
    }
    
    private func calculateHistogram(for image: UIImage) -> [UIColor: Int]? {
        guard let cgImage = image.cgImage,
              let pixelData = cgImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else { return nil }
        
        var histogram: [UIColor: Int] = [:]
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        
        // Sample every 10th pixel for performance
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                guard offset + 2 < CFDataGetLength(pixelData) else { continue }
                
                let r = CGFloat(data[offset]) / 255.0
                let g = CGFloat(data[offset + 1]) / 255.0
                let b = CGFloat(data[offset + 2]) / 255.0
                
                // Quantize for histogram
                let qR = round(r * 5) / 5
                let qG = round(g * 5) / 5
                let qB = round(b * 5) / 5
                
                let color = UIColor(red: qR, green: qG, blue: qB, alpha: 1.0)
                histogram[color, default: 0] += 1
            }
        }
        
        return histogram
    }
    
    // MARK: - Save to Photos
    
    private func saveDiagnosticImage(_ image: UIImage, title: String) async {
        // Request photo library permission
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized else {
            print("❌ Photo library permission denied")
            return
        }
        
        // Save image
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: image.pngData() ?? Data(), options: nil)
                
                // Add metadata
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = "ColorDiagnostic_\(title.replacingOccurrences(of: " ", with: "_"))_\(Date().timeIntervalSince1970).png"
                creationRequest.addResource(with: .photo, data: image.pngData() ?? Data(), options: options)
            }
            print("✅ Diagnostic image saved to Photos")
        } catch {
            print("❌ Failed to save diagnostic image: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func srgbToLinear(_ value: CGFloat) -> CGFloat {
        if value <= 0.04045 {
            return value / 12.92
        } else {
            return pow((value + 0.055) / 1.055, 2.4)
        }
    }
    
    private func alphaInfoString(_ info: CGImageAlphaInfo) -> String {
        switch info {
        case .none: return "None"
        case .premultipliedLast: return "Premultiplied Last"
        case .premultipliedFirst: return "Premultiplied First"
        case .last: return "Last"
        case .first: return "First"
        case .noneSkipLast: return "None Skip Last"
        case .noneSkipFirst: return "None Skip First"
        case .alphaOnly: return "Alpha Only"
        @unknown default: return "Unknown"
        }
    }
    
    private func bitmapInfoString(_ info: CGBitmapInfo) -> String {
        var components: [String] = []
        
        if info.contains(.alphaInfoMask) {
            components.append("Alpha Info Mask")
        }
        if info.contains(.floatComponents) {
            components.append("Float Components")
        }
        if info.contains(.byteOrderMask) {
            components.append("Byte Order Mask")
        }
        if info.contains(.byteOrder16Little) {
            components.append("16-bit Little Endian")
        }
        if info.contains(.byteOrder32Little) {
            components.append("32-bit Little Endian")
        }
        if info.contains(.byteOrder16Big) {
            components.append("16-bit Big Endian")
        }
        if info.contains(.byteOrder32Big) {
            components.append("32-bit Big Endian")
        }
        
        return components.isEmpty ? "None" : components.joined(separator: ", ")
    }
    
    private func colorModelString(_ model: CGColorSpaceModel) -> String {
        switch model {
        case .unknown: return "Unknown"
        case .monochrome: return "Monochrome"
        case .rgb: return "RGB"
        case .cmyk: return "CMYK"
        case .lab: return "Lab"
        case .deviceN: return "DeviceN"
        case .indexed: return "Indexed"
        case .pattern: return "Pattern"
        @unknown default: return "Unknown Model"
        }
    }
}