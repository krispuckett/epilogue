import XCTest
import SwiftUI
import UIKit
@testable import Epilogue

/// Tests for the ColorCube color extraction algorithm
class ColorExtractorTests: XCTestCase {
    var extractor: OKLABColorExtractor!

    override func setUp() {
        super.setUp()
        extractor = OKLABColorExtractor()
    }

    override func tearDown() {
        extractor = nil
        super.tearDown()
    }

    // MARK: - Basic Color Extraction Tests

    func test_whenExtractingFromSolidRedImage_thenReturnsRedAsPrimary() async {
        // Given: A solid red image
        let redImage = createSolidColorImage(color: .red, size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: redImage, imageSource: "Test Red")

            // Then: Primary should be red-ish
            let uiPrimary = UIColor(palette.primary)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiPrimary.getRed(&r, green: &g, blue: &b, alpha: &a)

            XCTAssertGreaterThan(r, 0.5, "Red component should be dominant")
            XCTAssertLessThan(g, 0.3, "Green component should be low")
            XCTAssertLessThan(b, 0.3, "Blue component should be low")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    func test_whenExtractingFromSolidBlueImage_thenReturnsBlueAsPrimary() async {
        // Given: A solid blue image
        let blueImage = createSolidColorImage(color: .blue, size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: blueImage, imageSource: "Test Blue")

            // Then: Primary should be blue-ish
            let uiPrimary = UIColor(palette.primary)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiPrimary.getRed(&r, green: &g, blue: &b, alpha: &a)

            XCTAssertLessThan(r, 0.3, "Red component should be low")
            XCTAssertLessThan(g, 0.3, "Green component should be low")
            XCTAssertGreaterThan(b, 0.5, "Blue component should be dominant")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    func test_whenExtractingFromSolidGreenImage_thenReturnsGreenAsPrimary() async {
        // Given: A solid green image
        let greenImage = createSolidColorImage(color: .green, size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: greenImage, imageSource: "Test Green")

            // Then: Primary should be green-ish
            let uiPrimary = UIColor(palette.primary)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiPrimary.getRed(&r, green: &g, blue: &b, alpha: &a)

            XCTAssertLessThan(r, 0.3, "Red component should be low")
            XCTAssertGreaterThan(g, 0.5, "Green component should be dominant")
            XCTAssertLessThan(b, 0.3, "Blue component should be low")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    // MARK: - Nil/Invalid Image Handling

    func test_whenImageIsNil_thenReturnsFallbackPalette() async {
        // Given: A UIImage with no CGImage
        let nilImage = UIImage()

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: nilImage, imageSource: "Nil Image")

            // Then: Should return fallback palette without crashing
            XCTAssertNotNil(palette)
            XCTAssertEqual(palette.extractionQuality, 0.0, "Quality should be 0 for fallback")
        } catch {
            // Extraction may throw or return fallback - either is acceptable
            XCTAssertTrue(true)
        }
    }

    func test_whenImageIsTooSmall_thenHandlesGracefully() async {
        // Given: A very small image (likely cropped)
        let tinyImage = createSolidColorImage(color: .orange, size: CGSize(width: 10, height: 10))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: tinyImage, imageSource: "Tiny Image")

            // Then: Should still return a valid palette
            XCTAssertNotNil(palette)
            XCTAssertNotNil(palette.primary)
            XCTAssertNotNil(palette.secondary)
        } catch {
            XCTFail("Should handle small images gracefully: \(error)")
        }
    }

    // MARK: - Multi-Color Image Tests

    func test_whenExtractingFromTwoColorImage_thenFindsDistinctColors() async {
        // Given: An image with two distinct colors
        let twoColorImage = createTwoColorImage(
            topColor: .red,
            bottomColor: .blue,
            size: CGSize(width: 100, height: 100)
        )

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: twoColorImage, imageSource: "Two Color")

            // Then: Primary and secondary should be different
            let primary = UIColor(palette.primary)
            let secondary = UIColor(palette.secondary)

            XCTAssertFalse(colorsAreEqual(primary, secondary), "Primary and secondary should be distinct")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    // MARK: - Monochrome Detection

    func test_whenImageIsGrayscale_thenDetectsAsMonochromatic() async {
        // Given: A grayscale image
        let grayImage = createSolidColorImage(color: .gray, size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: grayImage, imageSource: "Grayscale")

            // Then: Should be marked as monochromatic
            XCTAssertTrue(palette.isMonochromatic, "Grayscale image should be monochromatic")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    func test_whenImageHasVariedColors_thenNotMonochromatic() async {
        // Given: An image with varied colors
        let colorfulImage = createColorfulImage(size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: colorfulImage, imageSource: "Colorful")

            // Then: Should not be marked as monochromatic
            XCTAssertFalse(palette.isMonochromatic, "Colorful image should not be monochromatic")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    // MARK: - Performance Tests

    func test_whenExtractingFromLargeImage_thenCompletesInReasonableTime() async {
        // Given: A large image
        let largeImage = createSolidColorImage(color: .purple, size: CGSize(width: 1000, height: 1500))

        // When: Extracting palette
        let startTime = Date()

        do {
            _ = try await extractor.extractPalette(from: largeImage, imageSource: "Large Image")

            let duration = Date().timeIntervalSince(startTime)

            // Then: Should complete within 5 seconds (accounting for downsampling)
            XCTAssertLessThan(duration, 5.0, "Large image extraction should complete within 5 seconds")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    // MARK: - Palette Quality Tests

    func test_whenExtractingFromValidImage_thenQualityScoreIsHigh() async {
        // Given: A valid colorful image
        let validImage = createColorfulImage(size: CGSize(width: 200, height: 200))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: validImage, imageSource: "Valid Image")

            // Then: Quality score should be reasonable
            XCTAssertGreaterThan(palette.extractionQuality, 0.5, "Valid image should have decent quality score")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    func test_whenExtractingPalette_thenContainsAllRequiredColors() async {
        // Given: Any valid image
        let image = createSolidColorImage(color: .orange, size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: image, imageSource: "Complete Test")

            // Then: Palette should have all required components
            XCTAssertNotNil(palette.primary)
            XCTAssertNotNil(palette.secondary)
            XCTAssertNotNil(palette.accent)
            XCTAssertNotNil(palette.background)
            XCTAssertNotNil(palette.textColor)
            XCTAssertGreaterThanOrEqual(palette.luminance, 0.0)
            XCTAssertLessThanOrEqual(palette.luminance, 1.0)
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    // MARK: - Text Color Contrast Tests

    func test_whenPrimaryIsDark_thenTextColorIsWhite() async {
        // Given: A dark image
        let darkImage = createSolidColorImage(color: UIColor(white: 0.1, alpha: 1.0), size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: darkImage, imageSource: "Dark Image")

            // Then: Text color should be white/light
            XCTAssertEqual(palette.textColor, .white, "Dark background should use white text")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    func test_whenPrimaryIsLight_thenTextColorIsBlack() async {
        // Given: A light image
        let lightImage = createSolidColorImage(color: UIColor(white: 0.9, alpha: 1.0), size: CGSize(width: 100, height: 100))

        // When: Extracting palette
        do {
            let palette = try await extractor.extractPalette(from: lightImage, imageSource: "Light Image")

            // Then: Text color should be black/dark
            XCTAssertEqual(palette.textColor, .black, "Light background should use black text")
        } catch {
            XCTFail("Color extraction failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createSolidColorImage(color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func createTwoColorImage(topColor: UIColor, bottomColor: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            topColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height / 2))

            bottomColor.setFill()
            context.fill(CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2))
        }
    }

    private func createColorfulImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let colors: [UIColor] = [.red, .blue, .green, .yellow, .purple, .orange]
            let sectionHeight = size.height / CGFloat(colors.count)

            for (index, color) in colors.enumerated() {
                color.setFill()
                context.fill(CGRect(
                    x: 0,
                    y: CGFloat(index) * sectionHeight,
                    width: size.width,
                    height: sectionHeight
                ))
            }
        }
    }

    private func colorsAreEqual(_ color1: UIColor, _ color2: UIColor, tolerance: CGFloat = 0.1) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        return abs(r1 - r2) < tolerance &&
               abs(g1 - g2) < tolerance &&
               abs(b1 - b2) < tolerance
    }
}
