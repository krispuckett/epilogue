# Atmospheric Gradient System - Complete Rebuild Plan

## Executive Summary

This document outlines a comprehensive plan to rebuild the color extraction and gradient system for Epilogue to achieve 95%+ confidence on color extraction with intelligent gradient creation.

---

## Part 1: Current System Audit

### What Works
1. **ColorCube 16³ histogram** - Finds colors that exist in the image
2. **Multi-scale analysis for dark covers** - Catches small accent colors
3. **Local maxima detection** - Identifies distinct color peaks
4. **LOTR works** - Gold, red, black extraction is correct

### What's Broken

#### Problem 1: Role Assignment Logic
The current `assignColorRolesDirectly` function has flawed logic:
- For light covers: Filters for "vibrant" colors (saturation > 0.3) but this excludes books with intentionally muted palettes
- The sorting by frequency puts dominant background colors first, not the most visually important colors
- "Stillness is the Key" likely has cream/tan as most frequent but that's not visually interesting

#### Problem 2: No Perceptual Color Distance
- Uses raw RGB/HSB values which don't match human perception
- Two colors might look identical to humans but have different RGB values
- No clustering to merge perceptually similar colors

#### Problem 3: Single Extraction Strategy
- Same algorithm for all cover types
- Doesn't adapt to:
  - Photographic covers (continuous gradients)
  - Graphic design covers (flat colors)
  - Illustrated covers (textures)
  - Typography-heavy covers (small colored text on large background)

#### Problem 4: Quality/Confidence Metric is Meaningless
```swift
extractionQuality: min(Double(selectedColors.count) / 4.0, 1.0)
```
- Just checks if 4+ colors found
- Doesn't validate if colors are actually good
- Should measure: color diversity, visual interest, extraction confidence

---

## Part 2: Cover Classification System

### Cover Types to Detect

| Type | Characteristics | Strategy |
|------|-----------------|----------|
| **Dark** | >60% pixels L<0.2 | Boost bright accents aggressively |
| **Light** | >50% pixels L>0.8 | Find saturated focal points |
| **Vibrant** | Avg chroma >0.15 | Minimal enhancement |
| **Muted** | Avg chroma <0.05 | Boost significantly |
| **Monochromatic** | All hues within 30° | Create subtle variations |
| **Photographic** | High variance, smooth gradients | Sample focal regions |
| **Graphic** | Low variance, sharp edges | Direct color sampling |
| **Text-Heavy** | Small high-contrast regions | Focus on text colors |

### Detection Algorithm
```
1. Sample image at low resolution (64x64)
2. Calculate:
   - Lightness histogram
   - Chroma histogram
   - Hue variance
   - Edge density (Sobel)
   - Color cluster count
3. Classify based on thresholds
4. Route to specialized extractor
```

---

## Part 3: OKLCH-Based Extraction

### Why OKLCH?
- **Perceptually uniform** - Equal numeric distances = equal visual distances
- **Predictable hue** - H rotates around the color wheel as expected
- **Better for gradients** - Interpolation looks natural
- **Industry standard** - Used by CSS Color Level 4, Adobe, Figma

### Core Color Space Structure
```swift
struct OKLCHColor {
    let L: Double  // Lightness (0-1)
    let C: Double  // Chroma (0-0.4 typically)
    let H: Double  // Hue (0-360)

    var color: Color { /* convert to SwiftUI */ }

    func distance(to other: OKLCHColor) -> Double {
        // Weighted Euclidean in OKLAB space
    }
}
```

---

## Part 4: Improved Extraction Algorithm

### Phase 1: Preprocessing
1. Downsample to 256x256 (preserve aspect)
2. Optional edge detection to identify focal regions
3. Classify cover type

### Phase 2: Color Sampling
```
For each pixel:
  1. Convert RGB → OKLAB → OKLCH
  2. Quantize to 24³ color cube (finer than current 16³)
  3. Track pixel count per cube cell
  4. Track spatial distribution (center vs edges)
```

### Phase 3: Peak Detection
```
1. Find local maxima in 3D color cube
2. Merge peaks within perceptual distance < 0.05
3. Score peaks by:
   - Frequency (pixel count)
   - Spatial importance (center-weighted)
   - Visual interest (chroma × lightness balance)
   - Edge presence (focal vs background)
```

### Phase 4: Role Assignment
```
Primary: Highest scoring peak with C > 0.08 OR brightest if all muted
Secondary: Next peak with hue difference > 20° from primary
Accent: Most saturated peak not already assigned
Background: Darkest peak OR generated from primary at 20% lightness
```

### Phase 5: Validation
```
Quality Score = weighted sum of:
  - Hue diversity (0.3)
  - Lightness range (0.2)
  - Chroma presence (0.2)
  - Color count (0.15)
  - Spatial coverage (0.15)

If score < 0.6:
  - Try alternative extraction strategy
  - Fall back to default palette with warning
```

---

## Part 5: Gradient Generation

### Gradient Philosophy
The reference LOTR gradient shows:
- Primary color at TOP (gold/orange)
- Transition through secondary (red/orange)
- Fade through accent
- Deep into background (black)
- Fade to clear at 65%

### Gradient Stops Formula
```swift
func atmosphericStops(intensity: Double = 1.0) -> [Gradient.Stop] {
    [
        .init(color: primary.opacity(intensity), location: 0.0),
        .init(color: secondary.opacity(intensity * 0.85), location: 0.18),
        .init(color: accent.opacity(intensity * 0.55), location: 0.35),
        .init(color: background.opacity(intensity * 0.3), location: 0.5),
        .init(color: .clear, location: 0.65)
    ]
}
```

### Color Enhancement for Display
```swift
func enhanceForDisplay(coverType: CoverType) -> OKLCHColor {
    let config = coverType.enhancementConfig

    return OKLCHColor(
        L: clamp(L, config.minL, config.maxL),
        C: min(C * config.chromaMultiplier, config.maxC),
        H: H  // Preserve hue
    )
}
```

Enhancement configs by cover type:
| Type | Chroma× | Min L | Max L | Max C |
|------|---------|-------|-------|-------|
| Dark | 1.5 | 0.50 | 0.85 | 0.40 |
| Light | 1.4 | 0.35 | 0.75 | 0.35 |
| Vibrant | 1.1 | 0.40 | 0.80 | 0.35 |
| Muted | 1.8 | 0.45 | 0.80 | 0.35 |
| Mono | 1.3 | 0.40 | 0.85 | 0.25 |
| Balanced | 1.3 | 0.40 | 0.80 | 0.35 |

---

## Part 6: Implementation Phases

### Phase A: Foundation (Day 1)
1. Create `OKLCHColorSpace.swift` with proper OKLAB↔RGB conversion
2. Add perceptual distance calculations
3. Create test harness to compare old vs new extraction

### Phase B: Extraction Engine (Day 2)
1. Implement cover type classifier
2. Build new extraction pipeline with 24³ cube
3. Implement peak merging with perceptual distance
4. Add spatial weighting for center-bias

### Phase C: Role Assignment (Day 3)
1. New role assignment with hue diversity requirements
2. Quality scoring system
3. Fallback handling
4. A/B testing infrastructure

### Phase D: Gradient Generation (Day 4)
1. Update gradient view to use new palette
2. Implement per-cover-type enhancement
3. Add smooth transitions between palettes
4. Performance optimization

### Phase E: Validation & Polish (Day 5)
1. Test against 20+ known book covers
2. Fix edge cases
3. Add debug visualization tools
4. Documentation

---

## Part 7: Test Cases

### Must-Pass Books
| Book | Expected Primary | Expected Secondary | Notes |
|------|------------------|-------------------|-------|
| Lord of the Rings | Gold (#C4A84B) | Red/Orange (#B5453A) | Dark cover |
| Stillness is the Key | Gold (#D4A84B) | Orange/White | Dark cover with gold sunburst |
| The Odyssey | Teal | Dark Blue | Balanced |
| The Silmarillion | Blue | Gold | Should NOT be green |
| Love Wins | Blue | White/Light | Should NOT be red |

### Automated Testing
```swift
struct ColorExtractionTest {
    let bookName: String
    let coverURL: String
    let expectedPrimary: OKLCHColor
    let expectedSecondary: OKLCHColor
    let hueTolerance: Double = 15.0  // degrees
    let chromaTolerance: Double = 0.1
}
```

---

## Part 8: Performance Considerations

### Current Performance
- Extraction: ~50-100ms per image
- Memory: Single image in memory during extraction
- Cache: Disk + memory caching working

### Targets
- Extraction: <75ms for 400px image
- Memory: No increase
- Startup: Cache warming for visible books

### Optimizations
1. Use Accelerate framework for color conversion
2. SIMD operations for histogram building
3. Lazy evaluation of quality metrics
4. Aggressive downsampling for classification

---

## Part 9: Migration Path

### Backwards Compatibility
- Keep `ColorPalette` type as legacy interface
- Add `DisplayPalette.toLegacy()` conversion
- Gradual rollout with feature flag

### Rollout Strategy
1. New extraction behind flag
2. A/B test with 10% of extractions
3. Compare quality scores
4. Full rollout when confidence

---

## Part 10: Success Metrics

### Quantitative
- Extraction confidence: Mean >0.85, Min >0.60
- Hue diversity: At least 2 distinct hues (>30° apart) when present
- Processing time: <75ms p95

### Qualitative
- Visual review of 20 test covers
- No "obviously wrong" colors (purple on LOTR, etc.)
- Gradients feel "Apple Music-like"

---

## Appendix A: OKLAB Color Conversion

```swift
// sRGB → Linear RGB
func srgbToLinear(_ c: Double) -> Double {
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
}

// Linear RGB → OKLAB
func rgbToOKLAB(r: Double, g: Double, b: Double) -> (L: Double, a: Double, b: Double) {
    let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

    let l_ = cbrt(l)
    let m_ = cbrt(m)
    let s_ = cbrt(s)

    return (
        L: 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
        a: 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
        b: 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    )
}

// OKLAB → OKLCH
func oklabToOKLCH(L: Double, a: Double, b: Double) -> (L: Double, C: Double, H: Double) {
    let C = sqrt(a * a + b * b)
    let H = atan2(b, a) * 180 / .pi
    return (L, C, H < 0 ? H + 360 : H)
}
```

---

## Appendix B: File Structure

```
Epilogue/Core/Colors/
├── OKLCHColorSpace.swift      # Color space conversions
├── CoverClassifier.swift       # Cover type detection
├── ColorExtractor.swift        # Main extraction engine
├── RoleAssignment.swift        # Color role logic
├── DisplayPalette.swift        # Output palette type
├── GradientGenerator.swift     # Gradient creation
└── ExtractionQuality.swift     # Quality metrics

Epilogue/Core/Background/
└── AtmosphericGradientView.swift  # Gradient display
```

---

## Summary

The current system fails because:
1. Role assignment prioritizes frequency over visual importance
2. No perceptual color distance (HSB is not perceptually uniform)
3. Single extraction strategy for all cover types
4. No real quality validation

The new system will:
1. Classify covers and adapt extraction strategy
2. Use OKLCH for perceptual accuracy
3. Score colors by visual importance, not just frequency
4. Validate results with meaningful quality metrics
5. Generate gradients that match the Apple Music aesthetic
