import UIKit

@MainActor
enum ImageQualityEvaluator {
    /// Returns true if the image is likely grayscale/monotone using a quick HSV saturation check.
    /// Downscales to a small size for speed and samples all pixels.
    static func isLikelyGrayscale(_ image: UIImage,
                                  sampleSize: CGSize = CGSize(width: 64, height: 64),
                                  meanSaturationThreshold: CGFloat = 0.12,
                                  stdSaturationThreshold: CGFloat = 0.05) -> Bool {
        guard let cgImage = image.cgImage else { return false }

        // Draw into a small RGBA context
        let width = Int(sampleSize.width)
        let height = Int(sampleSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Compute saturation statistics in HSV
        var sats: [CGFloat] = []
        sats.reserveCapacity(width * height)

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(pixels[idx + 0]) / 255.0
                let g = CGFloat(pixels[idx + 1]) / 255.0
                let b = CGFloat(pixels[idx + 2]) / 255.0

                var h: CGFloat = 0
                var s: CGFloat = 0
                var v: CGFloat = 0
                rgbToHsv(r: r, g: g, b: b, h: &h, s: &s, v: &v)
                sats.append(s)
            }
        }

        guard !sats.isEmpty else { return false }
        let mean = sats.reduce(0, +) / CGFloat(sats.count)
        let variance = sats.reduce(0) { $0 + pow($1 - mean, 2) } / CGFloat(sats.count)
        let std = sqrt(variance)

        return mean < meanSaturationThreshold && std < stdSaturationThreshold
    }

    private static func rgbToHsv(r: CGFloat, g: CGFloat, b: CGFloat, h: inout CGFloat, s: inout CGFloat, v: inout CGFloat) {
        let maxV = max(r, max(g, b))
        let minV = min(r, min(g, b))
        v = maxV
        let delta = maxV - minV
        s = maxV == 0 ? 0 : delta / maxV
        if delta == 0 { h = 0; return }
        if maxV == r {
            h = (g - b) / delta + (g < b ? 6 : 0)
        } else if maxV == g {
            h = (b - r) / delta + 2
        } else {
            h = (r - g) / delta + 4
        }
        h /= 6
    }
}

