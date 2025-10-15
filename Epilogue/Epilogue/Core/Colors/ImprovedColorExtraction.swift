import SwiftUI
import UIImageColors

// Type alias to avoid confusion with the library name
typealias ImageColors = UIImageColors

// Improved color extraction with validation and fallbacks
struct ImprovedColorExtraction {
    
    // Extract colors with validation and intelligent role assignment
    static func extractColors(from image: UIImage, bookTitle: String) async -> ColorPalette? {
        #if DEBUG
        print("Starting improved color extraction for: \(bookTitle)")
        #endif
        
        // Removed hard-coded test - was causing inconsistent extractions
        
        // DEBUG: Save image to Photos - DISABLED
        // debugSaveExtractedImage(image, bookTitle: bookTitle)
        
        // Preprocess image to reduce text anti-aliasing artifacts
        let processedImage = preprocessImageForColorExtraction(image)
        
        // Try OKLAB first since it handles dark covers better
        #if DEBUG
        print("Trying OKLAB extractor (primary method)...")
        #endif
        let extractor = OKLABColorExtractor()
        if let cgImage = processedImage.cgImage {
            let palette = await extractor.extractPalette(from: cgImage, imageSource: bookTitle)
            #if DEBUG
            print("OKLAB extraction completed")
            #endif
            return palette
        }
        
        // Fallback 1: Try vibrant pixel finder for dark covers
        #if DEBUG
        print("Trying vibrant pixel finder...")
        #endif
        let vibrantColors = findVibrantColors(in: image)
        if vibrantColors.count >= 3 {
            #if DEBUG
            print("Found \(vibrantColors.count) vibrant colors")
            #endif
            return createPaletteFromVibrantColors(vibrantColors, bookTitle: bookTitle)
        }
        
        // Fallback 2: Try UIImageColors for light covers
        #if DEBUG
        print("Trying UIImageColors as fallback...")
        #endif
        if let colors = image.getColors(quality: .high) {
            // Only use if validation passes
            if validateExtractedColors(colors) {
                #if DEBUG
                print("UIImageColors extraction validated")
                #endif
                return intelligentRoleAssignment(colors)
            } else {
                #if DEBUG
                print("UIImageColors extraction failed validation")
                #endif
            }
        }
        
        // Fallback 3: Try extracting from center region
        if let centeredColors = extractFromCenterRegion(image) {
            if validateExtractedColors(centeredColors) {
                #if DEBUG
                print("Center region extraction succeeded")
                #endif
                return intelligentRoleAssignment(centeredColors)
            }
        }
        
        // Fallback 4: Enhance image and retry OKLAB
        #if DEBUG
        print("Trying enhanced image extraction...")
        #endif
        if let enhancedImage = enhanceImageForExtraction(image) {
            // DEBUG: Save enhanced image - DISABLED
            // print("📸 Saving ENHANCED image for \(bookTitle)")
            // UIImageWriteToSavedPhotosAlbum(enhancedImage, nil, nil, nil)
            
            if let cgImage = enhancedImage.cgImage {
                let enhancedPalette = await extractor.extractPalette(from: cgImage, imageSource: bookTitle)
                #if DEBUG
                print("Enhanced image extraction succeeded")
                #endif
                return enhancedPalette
            }
        }
        
        #if DEBUG
        print("All extraction methods failed")
        #endif
        return nil
    }
    
    // Validate that extracted colors are reasonable
    private static func validateExtractedColors(_ colors: ImageColors) -> Bool {
        // UIImageColors properties are implicitly unwrapped optionals
        guard let primary = colors.primary,
              let secondary = colors.secondary,
              let detail = colors.detail else {
            #if DEBUG
            print("Some colors are nil")
            #endif
            return false
        }
        
        let colorList = [primary, secondary, detail]
        var hues: [CGFloat] = []
        var saturations: [CGFloat] = []
        var brightnesses: [CGFloat] = []
        
        for color in colorList {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            hues.append(h)
            saturations.append(s)
            brightnesses.append(b)
        }
        
        // Check if all colors have very low saturation (grayscale)
        let avgSaturation = saturations.reduce(0, +) / CGFloat(saturations.count)
        if avgSaturation < 0.2 {
            #if DEBUG
            print("Low saturation detected (\(String(format: "%.2f", Double(avgSaturation)))) - likely grayscale")
            #endif
            return false
        }
        
        // Check if all colors are too dark
        let avgBrightness = brightnesses.reduce(0, +) / CGFloat(brightnesses.count)
        if avgBrightness < 0.2 {
            #if DEBUG
            print("All colors too dark (\(String(format: "%.2f", Double(avgBrightness))))")
            #endif
            return false
        }
        
        // Check if all hues are within 0.1 range AND low saturation
        let hueRange = (hues.max() ?? 0) - (hues.min() ?? 0)
        if hueRange < 0.1 && avgSaturation < 0.5 {
            #if DEBUG
            print("All colors too similar - hue range: \(String(format: "%.2f", Double(hueRange)))")
            #endif
            return false
        }
        
        return true
    }
    
    // Intelligently assign roles based on vibrancy
    private static func intelligentRoleAssignment(_ colors: ImageColors) -> ColorPalette {
        // Safely unwrap UIImageColors properties
        guard let primary = colors.primary,
              let secondary = colors.secondary,
              let detail = colors.detail,
              let background = colors.background else {
            #if DEBUG
            print("Failed to unwrap colors, using defaults")
            #endif
            return ColorPalette(
                primary: .red,
                secondary: .orange, 
                accent: .yellow,
                background: .black,
                textColor: .white,
                luminance: 0.5,
                isMonochromatic: false,
                extractionQuality: 0.0
            )
        }
        
        // Get brightness/saturation of each color
        let colorData = [
            (color: primary, role: "primary", original: primary),
            (color: secondary, role: "secondary", original: secondary),
            (color: detail, role: "detail", original: detail),
            (color: background, role: "background", original: background)
        ].map { item in
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
            item.color.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
            let vibrancy = s * b // Combined metric
            return (color: item.color, role: item.role, vibrancy: vibrancy, hue: h, saturation: s, brightness: b)
        }
        
        // Sort by vibrancy (most vibrant first)
        let sorted = colorData.sorted { $0.vibrancy > $1.vibrancy }
        
        #if DEBUG
        print("Color role assignment by vibrancy:")
        for (index, item) in sorted.enumerated() {
            #if DEBUG
            print("  \(index + 1). \(item.role): H=\(String(format: "%.2f", Double(item.hue))), S=\(String(format: "%.2f", Double(item.saturation))), B=\(String(format: "%.2f", Double(item.brightness))), V=\(String(format: "%.2f", Double(item.vibrancy)))")
            #endif
        }
        #endif
        
        // Create palette with most vibrant colors in primary positions
        guard sorted.count >= 4 else {
            // Fallback if we don't have enough colors
            let defaultColor = Color.gray
            return ColorPalette(
                primary: sorted.first.map { Color($0.color) } ?? defaultColor,
                secondary: sorted.dropFirst().first.map { Color($0.color) } ?? defaultColor.opacity(0.8),
                accent: sorted.dropFirst(2).first.map { Color($0.color) } ?? defaultColor.opacity(0.6),
                background: sorted.dropFirst(3).first.map { Color($0.color) } ?? Color.black,
                textColor: .white,
                luminance: 0.5,
                isMonochromatic: false,
                extractionQuality: 0.5
            )
        }
        
        return ColorPalette(
            primary: Color(sorted[0].color),    // Most vibrant
            secondary: Color(sorted[1].color),  // Second most vibrant
            accent: Color(sorted[2].color),     // Third
            background: Color(sorted[3].color), // Least vibrant (darkest)
            textColor: .white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 1.0
        )
    }
    
    // Extract from center region where important details often are
    private static func extractFromCenterRegion(_ image: UIImage) -> UIImageColors? {
        #if DEBUG
        print("Trying center region extraction...")
        #endif
        
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Crop to center 60% where logos/titles usually are
        let cropRect = CGRect(
            x: Int(Double(width) * 0.2),
            y: Int(Double(height) * 0.2),
            width: Int(Double(width) * 0.6),
            height: Int(Double(height) * 0.6)
        )
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        let croppedImage = UIImage(cgImage: croppedCGImage)
        
        // Extract from cropped image with highest quality
        return croppedImage.getColors(quality: .highest)
    }
    
    // Find vibrant colors by scanning pixels directly
    private static func findVibrantColors(in image: UIImage) -> [UIColor] {
        guard let cgImage = image.cgImage else { return [] }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Create context
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixelData = context.data else { return [] }
        
        var colorCounts: [UIColor: Int] = [:]
        let data = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        // Sample every 10th pixel for performance
        for y in stride(from: 0, to: height, by: 10) {
            for x in stride(from: 0, to: width, by: 10) {
                let offset = ((y * width) + x) * 4
                
                // BGRA format
                let b = CGFloat(data[offset]) / 255.0
                let g = CGFloat(data[offset + 1]) / 255.0
                let r = CGFloat(data[offset + 2]) / 255.0
                
                // Calculate saturation and brightness
                let maxRGB = max(r, g, b)
                let minRGB = min(r, g, b)
                let brightness = maxRGB
                let saturation = maxRGB > 0 ? (maxRGB - minRGB) / maxRGB : 0
                
                // Only keep vibrant colors (high saturation + brightness)
                if saturation > 0.4 && brightness > 0.4 {
                    // Quantize colors to reduce variations
                    let quantizedR = round(r * 10) / 10
                    let quantizedG = round(g * 10) / 10
                    let quantizedB = round(b * 10) / 10
                    let color = UIColor(red: quantizedR, green: quantizedG, blue: quantizedB, alpha: 1.0)
                    
                    colorCounts[color, default: 0] += 1
                }
            }
        }
        
        // Sort by frequency and vibrancy
        let sortedColors = colorCounts.sorted { (pair1, pair2) in
            // Calculate vibrancy score
            let color1 = pair1.key
            let color2 = pair2.key
            
            var h1: CGFloat = 0, s1: CGFloat = 0, b1: CGFloat = 0
            var h2: CGFloat = 0, s2: CGFloat = 0, b2: CGFloat = 0
            
            color1.getHue(&h1, saturation: &s1, brightness: &b1, alpha: nil)
            color2.getHue(&h2, saturation: &s2, brightness: &b2, alpha: nil)
            
            let vibrancy1 = s1 * b1 * CGFloat(pair1.value)
            let vibrancy2 = s2 * b2 * CGFloat(pair2.value)
            
            return vibrancy1 > vibrancy2
        }
        
        // Return top 4 most vibrant colors
        return Array(sortedColors.prefix(4).map { $0.key })
    }
    
    // Create palette from vibrant colors
    private static func createPaletteFromVibrantColors(_ colors: [UIColor], bookTitle: String) -> ColorPalette {
        #if DEBUG
        print("Creating palette from \(colors.count) vibrant colors")
        #endif
        
        // Ensure we have at least 4 colors
        var finalColors = colors
        while finalColors.count < 4 {
            if let lastColor = finalColors.last {
                // Create variations of the last color
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
                lastColor.getHue(&h, saturation: &s, brightness: &b, alpha: nil)
                
                // Add a lighter/darker variation
                if finalColors.count % 2 == 0 {
                    finalColors.append(UIColor(hue: h, saturation: s * 0.7, brightness: min(1.0, b * 1.3), alpha: 1.0))
                } else {
                    finalColors.append(UIColor(hue: h, saturation: min(1.0, s * 1.3), brightness: b * 0.7, alpha: 1.0))
                }
            } else {
                // Fallback colors
                finalColors.append(.systemRed)
            }
        }
        
        return ColorPalette(
            primary: Color(finalColors[0]),
            secondary: Color(finalColors[1]),
            accent: Color(finalColors[2]),
            background: Color(finalColors[3]).opacity(0.8),  // Make background darker
            textColor: .white,
            luminance: 0.5,
            isMonochromatic: false,
            extractionQuality: 0.8
        )
    }
    
    // Enhance image for better color extraction
    private static func enhanceImageForExtraction(_ image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Apply filters to enhance colors
        var outputImage = ciImage
        
        // Increase saturation and contrast
        if let colorControlsFilter = CIFilter(name: "CIColorControls") {
            colorControlsFilter.setValue(outputImage, forKey: kCIInputImageKey)
            colorControlsFilter.setValue(2.0, forKey: kCIInputSaturationKey)  // Boost saturation
            colorControlsFilter.setValue(1.5, forKey: kCIInputContrastKey)    // Increase contrast
            colorControlsFilter.setValue(0.2, forKey: kCIInputBrightnessKey)  // Slight brightness boost
            outputImage = colorControlsFilter.outputImage ?? outputImage
        }
        
        // Apply vibrance filter
        if let vibranceFilter = CIFilter(name: "CIVibrance") {
            vibranceFilter.setValue(outputImage, forKey: kCIInputImageKey)
            vibranceFilter.setValue(1.0, forKey: "inputAmount")
            outputImage = vibranceFilter.outputImage ?? outputImage
        }
        
        // Convert back to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    // DEBUG: Save image to Photos app to verify what's being extracted
    private static func debugSaveExtractedImage(_ image: UIImage, bookTitle: String) {
        // Debug saving disabled - no longer saves to photo library
        /*
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        #if DEBUG
        print("SAVED IMAGE TO PHOTOS for \(bookTitle) - CHECK IF IT MATCHES!")
        #endif
        #if DEBUG
        print("   Image size: \(image.size)")
        #endif
        #if DEBUG
        print("   Scale: \(image.scale)")
        #endif
        
        // Verify we have a full cover
        if image.size.width < 100 || image.size.height < 100 {
            #if DEBUG
            print("⚠️ WARNING: Image too small (\(image.size.width)x\(image.size.height)), likely cropped!")
            #endif
            #if DEBUG
            print("   This may be caused by zoom parameter - consider using zoom=0 or zoom=1")
            #endif
        }
        */
    }
    
    // Preprocess image to reduce text anti-aliasing artifacts
    private static func preprocessImageForColorExtraction(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        // Apply slight Gaussian blur to reduce edge artifacts from text
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(1.0, forKey: kCIInputRadiusKey) // Very slight blur
        
        guard let outputImage = filter?.outputImage else { return image }
        
        // Crop the output to original bounds (blur extends the image)
        let croppedImage = outputImage.cropped(to: ciImage.extent)
        
        // Convert back to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(croppedImage, from: croppedImage.extent) else { return image }
        
        let processedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        #if DEBUG
        print("🔧 Applied preprocessing: slight blur to reduce text artifacts")
        #endif
        
        return processedImage
    }
    
    // TEMPORARY: Test with known good URL
    /* COMMENTED OUT - Was causing multiple extractions and inconsistent results
    private static func testWithKnownGoodURL(bookTitle: String) async -> ColorPalette? {
        #if DEBUG
        print("\n🧪 HARD-CODED URL TEST")
        #endif
        
        // Known good LOTR URLs from Google Books
        let testURLs = [
            "https://books.google.com/books/content?id=yl4dILkcqm4C&printsec=frontcover&img=1&source=gbs_api&w=1080",
            "https://books.google.com/books/content?id=yl4dILkcqm4C&printsec=frontcover&img=1&source=gbs_api",
            "https://books.google.com/books/content?id=yl4dILkcqm4C&printsec=frontcover&img=1&zoom=0&source=gbs_api"
        ]
        
        for (index, urlString) in testURLs.enumerated() {
            #if DEBUG
            print("\n📍 Testing URL \(index + 1): \(urlString)")
            #endif
            
            guard let url = URL(string: urlString) else {
                #if DEBUG
                print("❌ Invalid URL")
                #endif
                continue
            }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else {
                    #if DEBUG
                    print("❌ Could not create image from data")
                    #endif
                    continue
                }
                
                #if DEBUG
                print("✅ Downloaded image: \(image.size)")
                #endif
                
                // Save to Photos for inspection - DISABLED
                // UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                // print("📸 SAVED TEST IMAGE #\(index + 1) TO PHOTOS")
                
                // Try extraction
                let extractor = OKLABColorExtractor()
                if let palette = try? await extractor.extractPalette(from: image, imageSource: "LOTR_TEST_\(index + 1)") {
                    #if DEBUG
                    print("🎨 EXTRACTION SUCCESSFUL!")
                    #endif
                    #if DEBUG
                    print("  Primary: \(palette.uiColors.primary)")
                    #endif
                    #if DEBUG
                    print("  Secondary: \(palette.uiColors.secondary)")
                    #endif
                    #if DEBUG
                    print("  Accent: \(palette.uiColors.accent)")
                    #endif
                    
                    // If we get good colors (gold/red), return this palette
                    var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0
                    palette.uiColors.primary.getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)
                    let hueInDegrees = Int(hue * 360)
                    
                    #if DEBUG
                    print("  Primary hue: \(hueInDegrees)°")
                    #endif
                    
                    // Gold should be around 45°, red around 0-20°
                    if (hueInDegrees >= 30 && hueInDegrees <= 60) || (hueInDegrees >= 0 && hueInDegrees <= 30) {
                        #if DEBUG
                        print("✅ FOUND CORRECT COLORS! Using this palette.")
                        #endif
                        return palette
                    } else {
                        #if DEBUG
                        print("❌ Still getting wrong colors (hue: \(hueInDegrees)°)")
                        #endif
                    }
                }
            } catch {
                #if DEBUG
                print("❌ Error downloading: \(error)")
                #endif
            }
        }
        
        #if DEBUG
        print("\n❌ All test URLs failed")
        #endif
        return nil
    }
    */
}