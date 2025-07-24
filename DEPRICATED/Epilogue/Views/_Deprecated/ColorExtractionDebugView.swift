import SwiftUI
import CoreImage

struct ColorExtractionDebugView: View {
    let bookCoverImage: UIImage
    let bookTitle: String
    
    @State private var extractedColors: [Color] = []
    @State private var debugInfo: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Original image
                Image(uiImage: bookCoverImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 300)
                    .cornerRadius(10)
                
                Text("Extracted Colors")
                    .font(.headline)
                
                // Color swatches
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                    ForEach(extractedColors.indices, id: \.self) { index in
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(extractedColors[index])
                                .frame(height: 60)
                            
                            Text(colorToHex(extractedColors[index]))
                                .font(.caption)
                                .monospaced()
                        }
                    }
                }
                .padding()
                
                // Debug info
                Text("Debug Info")
                    .font(.headline)
                
                Text(debugInfo)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                // Test gradients
                Text("Gradient Tests")
                    .font(.headline)
                
                // Test 1: Raw extracted colors
                VStack(alignment: .leading) {
                    Text("Raw Colors")
                        .font(.caption)
                    LinearGradient(
                        colors: extractedColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 60)
                    .cornerRadius(8)
                }
                
                // Test 2: With blur
                VStack(alignment: .leading) {
                    Text("With Blur (radius: 80)")
                        .font(.caption)
                    LinearGradient(
                        colors: extractedColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .blur(radius: 80)
                    .frame(height: 60)
                    .cornerRadius(8)
                }
                
                // Test 3: With blur and blend mode
                VStack(alignment: .leading) {
                    Text("With Blur + .plusLighter")
                        .font(.caption)
                    ZStack {
                        Color.black
                        LinearGradient(
                            colors: extractedColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .blur(radius: 80)
                        .blendMode(.plusLighter)
                    }
                    .frame(height: 60)
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle("Color Debug: \(bookTitle)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            extractColors()
        }
    }
    
    private func colorToHex(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    
    private func extractColors() {
        guard let cgImage = bookCoverImage.cgImage else { return }
        
        var info = "Image size: \(cgImage.width)x\(cgImage.height)\n"
        
        // Extract colors using the same logic as CinematicBookGradient
        let colors = extractAllUniqueColors(from: cgImage)
        extractedColors = Array(colors.prefix(10))
        
        info += "Total colors extracted: \(colors.count)\n\n"
        
        // Analyze each color
        for (index, color) in extractedColors.enumerated() {
            let uiColor = UIColor(color)
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            
            var r: CGFloat = 0, g: CGFloat = 0, blue: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &blue, alpha: nil)
            
            info += "Color \(index):\n"
            info += "  RGB: \(colorToHex(color))\n"
            info += "  HSB: H:\(String(format: "%.2f", h)) S:\(String(format: "%.2f", s)) B:\(String(format: "%.2f", b))\n"
            info += "  Blue component: \(String(format: "%.2f", blue))\n"
            
            // Check if it would be considered "blue"
            if h > 0.5 && h < 0.75 {
                info += "  ⚠️ In blue hue range!\n"
            }
            info += "\n"
        }
        
        debugInfo = info
    }
    
    private func extractAllUniqueColors(from cgImage: CGImage) -> [Color] {
        // Same extraction logic as CinematicBookGradient
        let maxDimension: CGFloat = 300
        let scale = min(maxDimension / CGFloat(cgImage.width), maxDimension / CGFloat(cgImage.height))
        let newWidth = Int(CGFloat(cgImage.width) * scale)
        let newHeight = Int(CGFloat(cgImage.height) * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * newWidth
        
        var pixelData = [UInt8](repeating: 0, count: newWidth * newHeight * bytesPerPixel)
        
        guard let context = CGContext(
            data: &pixelData,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(newWidth), height: CGFloat(newHeight)))
        
        var colorMap: [String: (color: Color, count: Int)] = [:]
        
        for y in stride(from: 0, to: newHeight, by: 2) {
            for x in stride(from: 0, to: newWidth, by: 2) {
                let index = ((newWidth * y) + x) * bytesPerPixel
                
                let r = CGFloat(pixelData[index]) / 255.0
                let g = CGFloat(pixelData[index + 1]) / 255.0
                let b = CGFloat(pixelData[index + 2]) / 255.0
                
                let uiColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0
                uiColor.getHue(&h, saturation: &s, brightness: &br, alpha: nil)
                
                let brightness = (r + g + b) / 3.0
                
                if (s > 0.15 || brightness < 0.1) && !(r > 0.95 && g > 0.95 && b > 0.95) {
                    let roundedR = round(r * 20) / 20
                    let roundedG = round(g * 20) / 20
                    let roundedB = round(b * 20) / 20
                    
                    let key = "\(roundedR)-\(roundedG)-\(roundedB)"
                    
                    if let existing = colorMap[key] {
                        colorMap[key] = (existing.color, existing.count + 1)
                    } else {
                        let color = Color(red: r, green: g, blue: b)
                        colorMap[key] = (color, 1)
                    }
                }
            }
        }
        
        let sortedColors = colorMap.values
            .filter { $0.count > 10 }
            .sorted { entry1, entry2 in
                let ui1 = UIColor(entry1.color)
                let ui2 = UIColor(entry2.color)
                var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
                var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
                ui1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
                ui2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
                
                if b1 < 0.1 && b2 >= 0.1 { return true }
                if b2 < 0.1 && b1 >= 0.1 { return false }
                
                if s1 > 0.7 && s2 <= 0.7 { return true }
                if s2 > 0.7 && s1 <= 0.7 { return false }
                
                let score1 = s1 * (1.0 + CGFloat(entry1.count) / 100.0)
                let score2 = s2 * (1.0 + CGFloat(entry2.count) / 100.0)
                
                return score1 > score2
            }
            .prefix(10)
            .map { $0.color }
        
        return Array(sortedColors)
    }
}