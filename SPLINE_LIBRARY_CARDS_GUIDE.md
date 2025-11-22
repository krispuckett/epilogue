# 📚 Spline 3D Library Cards for Epilogue - Complete Implementation Guide

## Overview
Create beautiful, interactive 3D library cards for Epilogue's year-end review feature using Spline with gyroscope-controlled parallax effects. Users can tilt their device to interact with their reading stats in 3D.

**Inspired by**: [Gábor Pribék's Spline work](https://x.com/gaborpribek/status/1990812473847435445)
**Based on**: [gyro-spline repository](https://github.com/kapor00/gyro-spline)

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [Designing Cards in Spline](#designing-cards-in-spline)
3. [iOS Integration](#ios-integration)
4. [Gyroscope Controls](#gyroscope-controls)
5. [Card Design Templates](#card-design-templates)
6. [Performance Optimization](#performance-optimization)

---

## Quick Start

### Prerequisites
- Spline account: [spline.design](https://spline.design)
- Xcode 16.0+
- iOS 26.0+ (matches your current iOS 26 Liquid Glass setup)
- Physical iOS device (gyroscope doesn't work in simulator)

### Dependencies
Add SplineRuntime to your project:

```swift
// In Xcode: File → Add Package Dependencies
// URL: https://github.com/splinetool/spline-ios
// Version: 0.2.46 or later
```

---

## Part 1: Designing Cards in Spline

### Card Type 1: Glass Library Card (Matches iOS 26 Aesthetic)

**Visual Concept**: Frosted glass card with book colors, floating stats, gyro parallax

#### Step-by-Step in Spline:

**1. Setup Canvas** (spline.design → New Project)
- Canvas size: 1080x1920 (9:16 portrait)
- Background: Gradient using book's extracted colors

**2. Create Card Base**
```
Add → Rectangle
- Width: 800px, Height: 1200px, Depth: 50px
- Border Radius: 40px (all corners)
- Material:
  - Type: Glass
  - Transparency: 0.25
  - Blur: 25-30
  - Metalness: 0
  - Roughness: 0.1
  - Tint: Slight white overlay
- Name: "CardBase" (important for iOS control)
```

**3. Create Background Gradient Plane**
```
Add → Plane (behind card)
- Scale: 1500x2500 (larger than card)
- Material: Gradient
  - Top color: Use Epilogue's primary book color (enhanced)
  - Bottom color: Use secondary book color (enhanced)
  - Gradient type: Linear, vertical
- Position Z: -200 (behind card)
- Name: "Background"
```

**4. Add 3D Text Elements**
```
Add → 3D Text
- Content: "247" (example stat)
- Font: Bold, Size: 180px
- Extrude: 40px
- Bevel: Round, 5px
- Material: Gradient (primary → accent color)
- Position: Center-top of card, Z: 100 (in front)
- Name: "HeroStat"

Add → 3D Text (subtitle)
- Content: "HOURS READ"
- Font: Medium, Size: 36px
- Extrude: 20px
- Material: Solid color (white/primary)
- Position: Below hero stat
- Name: "StatLabel"
```

**5. Add Floating Book Icons/Decorations**
```
Add → Custom shapes or import SVG icons
- Position at varying Z-depths (50, 150, 250)
- This creates parallax effect when gyro moves
- Material: Subtle glow
- Name: "FloatingElement1", "FloatingElement2", etc.
```

**6. Lighting Setup**
```
Add → Point Light
- Color: Book's accent color (slightly desaturated)
- Position: (0, 500, 400) - above and in front
- Intensity: 1.5
- Shadows: Soft, 30% opacity
- Name: "AccentLight"

Add → Ambient Light
- Color: Warm white
- Intensity: 0.4

Add → Directional Light
- Angle: 45° from top-right
- Intensity: 0.8
- Creates card depth
```

**7. Camera Setup**
```
Select Main Camera
- Position: (0, 0, 1200)
- Rotation: (0, 0, 0)
- Field of View: 45°
- This gives slight perspective depth
```

**8. Object Hierarchy for Gyro Control**
Create a parent group that will respond to gyroscope:
```
In Layers Panel:
- Create Group → Name: "GyroGroup"
- Move into GyroGroup:
  - CardBase
  - HeroStat
  - StatLabel
  - FloatingElement1, 2, 3
  - AccentLight
- Keep Background outside group (static)
```

**9. Optional: Add Subtle Animation**
```
Timeline → Create Animation
- Select FloatingElement1
- 0s: Position Y = 0, Opacity = 0
- 1s: Position Y = 20, Opacity = 1
- 3s: Position Y = 0, Opacity = 1
- Loop: Infinite, Ease: In/Out
- Repeat for other floating elements with stagger
```

**10. Export Settings**
```
Export → Code
- Platform: iOS
- Format: SwiftUI (.splineswift)
- Options:
  ✓ Include assets
  ✓ Optimize for size
  ✗ Bake animations (we want dynamic control)
```

**Two Export Methods**:

**A. Cloud Export** (Easier, Requires Internet)
- Click "Publish to Web"
- Copy the `.splineswift` URL
- Example: `https://build.spline.design/[ID]/scene.splineswift`

**B. Local Export** (Offline, Larger App Size)
- Download `.splineswift` file
- Add to Xcode project → Copy items if needed
- Store in bundle

---

### Card Type 2: Book Stack Scene

**Visual Concept**: 3D stack of user's top 5 books with gyro tilt

#### Spline Instructions:
```
1. Add → Box (for each book)
   - Dimensions: 150 x 220 x 30 (book proportions)
   - Stack 5 books at slight angles
   - Position Z: Stagger 0, 35, 70, 105, 140

2. Apply Cover Textures
   - Import book cover images
   - Material: Image texture on front face
   - Use color extraction for spine colors

3. Add Spotlight
   - Position: Rotating around stack
   - Color: Warm white
   - Creates dramatic shadows

4. GyroGroup: All books together
   - User tilts device → stack rotates
   - Books maintain relative positions

5. Camera: Orbits slowly around stack (optional)
```

---

### Card Type 3: Achievement Badge Constellation

**Visual Concept**: Floating 3D badges in space, gyro reveals depth

#### Spline Instructions:
```
1. Create Badge Base (repeat 5-8 times)
   - Add → Cylinder (low height for medal)
   - Diameter: 120px, Height: 20px
   - Chamfer edges for polish

2. Materials by Achievement Level
   - Gold: Metalness: 0.9, Color: #FFD700
   - Silver: Metalness: 0.95, Color: #C0C0C0
   - Bronze: Metalness: 0.8, Color: #CD7F32

3. Position in 3D Grid
   - Vary Z-depth: -300 to +300
   - Creates layers for parallax

4. Add Icon/Number to Each Badge
   - 3D Text: "50" (books read)
   - Extrude: 15px
   - Position on badge surface

5. GyroGroup: All badges
   - Small tilt = large visual shift
   - Shows true 3D depth
```

---

## Part 2: iOS Integration

### Step 1: Add SplineRuntime Package

In Xcode (Epilogue project):
```
1. File → Add Package Dependencies
2. Search: https://github.com/splinetool/spline-ios
3. Version: 0.2.46 or later
4. Add to Epilogue target
```

### Step 2: Create Motion Manager

Create new file: `Epilogue/Core/Motion/MotionManager.swift`

```swift
//
//  MotionManager.swift
//  Epilogue
//
//  Handles device motion for interactive 3D scenes
//

import CoreMotion
import Combine

/// Manages device accelerometer/gyroscope for interactive 3D effects
class MotionManager: ObservableObject {
    private let motion = CMMotionManager()

    /// Published accelerometer data for SwiftUI bindings
    @Published var accelerometerData: CMAccelerometerData?

    /// Whether motion tracking is active
    @Published var isTracking: Bool = false

    init() {
        // Don't auto-start - let views control when needed
    }

    /// Start accelerometer updates at 100 FPS
    func startTracking() {
        guard motion.isAccelerometerAvailable else {
            print("⚠️ Accelerometer not available")
            return
        }

        motion.accelerometerUpdateInterval = 1.0 / 100.0 // 100 FPS
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            if let error = error {
                print("❌ Accelerometer error: \(error)")
                return
            }

            if let data = data {
                self?.accelerometerData = data
                self?.isTracking = true
            }
        }

        print("🎮 Motion tracking started")
    }

    /// Stop accelerometer updates to save battery
    func stopTracking() {
        motion.stopAccelerometerUpdates()
        isTracking = false
        print("🎮 Motion tracking stopped")
    }

    deinit {
        stopTracking()
    }
}
```

### Step 3: Create Spline Card View

Create new file: `Epilogue/Features/YearEnd/Views/SplineLibraryCardView.swift`

```swift
//
//  SplineLibraryCardView.swift
//  Epilogue
//
//  Interactive 3D library card with gyroscope control
//

import SwiftUI
import SplineRuntime
import CoreMotion

struct SplineLibraryCardView: View {
    // MARK: - Properties

    /// Spline scene controller
    private var splineController = SplineController()

    /// Motion manager for gyroscope
    @StateObject private var motionManager = MotionManager()

    /// Smoothed rotation values for fluid motion
    @State private var smoothedRotationX: Double = 0
    @State private var smoothedRotationY: Double = 0

    /// Configuration
    let sceneURL: URL
    let gyroObjectName: String // Name of object in Spline to control

    // MARK: - Initialization

    init(sceneURL: URL, gyroObjectName: String = "GyroGroup") {
        self.sceneURL = sceneURL
        self.gyroObjectName = gyroObjectName
    }

    // Convenience init for cloud-hosted scene
    init(sceneID: String, gyroObjectName: String = "GyroGroup") {
        self.sceneURL = URL(string: "https://build.spline.design/\(sceneID)/scene.splineswift")!
        self.gyroObjectName = gyroObjectName
    }

    // Convenience init for bundled scene
    init(bundledScene: String, gyroObjectName: String = "GyroGroup") {
        self.sceneURL = Bundle.main.url(forResource: bundledScene, withExtension: "splineswift")!
        self.gyroObjectName = gyroObjectName
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Spline 3D Scene
            SplineView(sceneFileURL: sceneURL, controller: splineController)
                .ignoresSafeArea()
                .onChange(of: motionManager.accelerometerData) { _, newData in
                    guard let accelData = newData else { return }
                    updateGyroRotation(from: accelData)
                }

            // Optional: Debug overlay (remove in production)
            #if DEBUG
            debugOverlay
            #endif
        }
        .onAppear {
            motionManager.startTracking()
        }
        .onDisappear {
            motionManager.stopTracking()
        }
    }

    // MARK: - Gyro Logic

    /// Update 3D object rotation based on device tilt
    private func updateGyroRotation(from accelData: CMAccelerometerData) {
        // Convert accelerometer data to rotation angles
        let scaleFactor = 60.0 // Degrees of rotation range

        // Map Y-axis tilt to X rotation (pitch)
        let targetX: Double = {
            let v = accelData.acceleration.y
            if v <= -0.5 {
                // Device tilted forward: -0.5 to -1.0 → 0° to 60°
                return (-0.5 - v) / 0.5 * 60
            } else {
                // Device tilted back: 1.0 to -0.5 → -60° to 0°
                return (v - 1.0) / (-0.5 - 1.0) * 60 - 60
            }
        }()

        // Map X-axis tilt to Y rotation (yaw)
        let targetY = accelData.acceleration.x * scaleFactor

        // Exponential smoothing for fluid motion
        // Lower value = smoother, Higher value = more responsive
        let smoothingFactor = 0.1
        smoothedRotationX += (targetX - smoothedRotationX) * smoothingFactor
        smoothedRotationY += (targetY - smoothedRotationY) * smoothingFactor

        // Apply rotation to Spline object
        if let gyroObject = splineController.findObject(name: gyroObjectName) {
            gyroObject.rotation.x = Float(smoothedRotationX)
            gyroObject.rotation.y = Float(smoothedRotationY)
        } else {
            print("⚠️ Gyro object '\(gyroObjectName)' not found in scene")
        }
    }

    // MARK: - Debug Overlay

    #if DEBUG
    private var debugOverlay: some View {
        VStack(spacing: 16) {
            Text("Gyroscope Debug")
                .font(.headline)
                .foregroundColor(.white)

            if let data = motionManager.accelerometerData {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Accel X: \(data.acceleration.x, specifier: "%.2f")")
                    Text("Accel Y: \(data.acceleration.y, specifier: "%.2f")")
                    Text("Accel Z: \(data.acceleration.z, specifier: "%.2f")")
                    Text("Rotation X: \(smoothedRotationX, specifier: "%.1f")°")
                    Text("Rotation Y: \(smoothedRotationY, specifier: "%.1f")°")
                }
                .font(.caption.monospaced())
                .foregroundColor(.white)
            } else {
                Text("No motion data")
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding()
        .background(.black.opacity(0.5))
        .allowsHitTesting(false)
    }
    #endif
}

// MARK: - Preview

#Preview("Cloud Scene") {
    SplineLibraryCardView(
        sceneID: "3ZUphPIRLkYxk1Y4pCFQ", // Example from gyro-spline
        gyroObjectName: "Subject"
    )
}

#Preview("Bundled Scene") {
    SplineLibraryCardView(
        bundledScene: "year_end_card",
        gyroObjectName: "GyroGroup"
    )
}
```

### Step 4: Integrate with Year-End Review

Create wrapper view: `Epilogue/Features/YearEnd/Views/YearEndReviewCardView.swift`

```swift
//
//  YearEndReviewCardView.swift
//  Epilogue
//
//  Year-end review card that combines user data with Spline 3D
//

import SwiftUI
import SplineRuntime

struct YearEndReviewCardView: View {
    // MARK: - Properties

    let stats: ReadingStats // Your existing reading stats model
    let cardStyle: CardStyle

    enum CardStyle {
        case glassCard
        case bookStack
        case achievements

        var sceneFileName: String {
            switch self {
            case .glassCard: return "glass_library_card"
            case .bookStack: return "book_stack_card"
            case .achievements: return "achievement_badges"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Base Spline scene
            SplineLibraryCardView(
                bundledScene: cardStyle.sceneFileName,
                gyroObjectName: "GyroGroup"
            )

            // Overlay dynamic data (if needed)
            // You can update Spline text objects programmatically
            // or overlay SwiftUI text for easier updates

            VStack {
                Spacer()

                // Example: Stats overlay
                statsOverlay
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            updateSplineWithStats()
        }
    }

    // MARK: - Stats Overlay

    private var statsOverlay: some View {
        VStack(spacing: 8) {
            Text("\(stats.totalHours)")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white)

            Text("HOURS READ")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Update Spline Objects

    /// Update Spline text objects with actual user data
    private func updateSplineWithStats() {
        // If your Spline scene has text objects with specific names
        // you can update them programmatically:

        // Note: SplineController would need to be accessible
        // This is pseudocode - adjust based on SplineRuntime API

        /*
        if let heroStatText = splineController.findObject(name: "HeroStat") {
            // Update text content (check SplineRuntime docs for exact API)
            heroStatText.text = "\(stats.totalHours)"
        }
        */
    }
}

// MARK: - Reading Stats Model

struct ReadingStats {
    let totalHours: Int
    let booksCompleted: Int
    let pagesRead: Int
    let genresExplored: Int
    let longestStreak: Int
    let topBooks: [Book]

    // Example factory
    static var preview: ReadingStats {
        ReadingStats(
            totalHours: 247,
            booksCompleted: 52,
            pagesRead: 18432,
            genresExplored: 12,
            longestStreak: 47,
            topBooks: []
        )
    }
}
```

### Step 5: Add to Year-End Flow

Update your year-end review flow to include the card:

```swift
// In your existing year-end feature
NavigationLink("View Your Year in Reading") {
    YearEndReviewCardView(
        stats: calculateYearStats(), // Your existing logic
        cardStyle: .glassCard
    )
}
```

---

## Part 3: Gyroscope Controls Explained

### How It Works

**Device Tilt → Accelerometer Data → 3D Rotation**

```
User tilts iPhone forward:
→ accelerometerData.y decreases
→ targetX increases (pitch rotation)
→ smoothedRotationX gradually moves to targetX
→ Spline object.rotation.x updates
→ Card tilts in 3D space
```

### Smoothing Algorithm

```swift
// Exponential smoothing prevents jittery motion
smoothedRotationX += (targetX - smoothedRotationX) * smoothingFactor

// smoothingFactor: 0.05 = Very smooth, slow
//                  0.1  = Balanced (recommended)
//                  0.3  = Fast, responsive
//                  1.0  = No smoothing (instant, jerky)
```

### Customizing Sensitivity

Adjust in `SplineLibraryCardView.swift`:

```swift
// More rotation range (more dramatic)
let scaleFactor = 90.0 // Default: 60.0

// Less rotation range (subtle)
let scaleFactor = 30.0

// More responsive
let smoothingFactor = 0.2 // Default: 0.1

// Smoother
let smoothingFactor = 0.05
```

### Rotation Axis Mapping

```swift
// Current mapping:
accelData.x (left/right tilt) → Y-axis rotation (yaw)
accelData.y (forward/back tilt) → X-axis rotation (pitch)

// To also add roll:
let targetZ = accelData.z * scaleFactor
smoothedRotationZ += (targetZ - smoothedRotationZ) * smoothingFactor
gyroObject.rotation.z = Float(smoothedRotationZ)
```

---

## Part 4: Performance Optimization

### 1. Reduce Scene Complexity in Spline

```
✅ Target polygon count: <50,000 triangles
✅ Use texture atlases (combine small textures)
✅ Bake lighting when possible (less real-time lights)
✅ Use lower-poly models for background elements
```

### 2. iOS Optimization

```swift
// In SplineLibraryCardView

// Only track motion when view is visible
.onAppear { motionManager.startTracking() }
.onDisappear { motionManager.stopTracking() }

// Reduce update frequency if needed
motion.accelerometerUpdateInterval = 1.0 / 60.0 // 60 FPS instead of 100
```

### 3. Loading States

```swift
struct SplineLibraryCardView: View {
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading your card...")
                    .foregroundStyle(.white)
            }

            SplineView(sceneFileURL: sceneURL, controller: splineController)
                .opacity(isLoading ? 0 : 1)
                .onAppear {
                    // Give scene time to load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            isLoading = false
                        }
                    }
                }
        }
    }
}
```

### 4. Memory Management

```swift
// Use cloud hosting for multiple card variations
// Instead of bundling 5 different .splineswift files (large),
// host on Spline cloud and load on-demand

let cardScenes: [CardStyle: String] = [
    .glassCard: "https://build.spline.design/ABC123/scene.splineswift",
    .bookStack: "https://build.spline.design/DEF456/scene.splineswift",
    .achievements: "https://build.spline.design/GHI789/scene.splineswift"
]
```

---

## Part 5: Card Design Templates

### Template 1: Glass Reading Stats Card

**Spline Scene Structure**:
```
Scene Root
├── Background (static gradient)
└── GyroGroup (responds to tilt)
    ├── CardBase (glass rectangle)
    ├── HeroStat (3D text: "247")
    ├── StatLabel (3D text: "HOURS READ")
    ├── FloatingBook1 (icon, Z: 50)
    ├── FloatingBook2 (icon, Z: 150)
    ├── FloatingBook3 (icon, Z: 250)
    └── AccentLight (point light)
```

**Color Integration**:
```swift
// Extract colors from user's top book
let primaryColor = extractedPalette.primary // From your existing system
let secondaryColor = extractedPalette.secondary

// Set in Spline:
// Background gradient: primaryColor → secondaryColor
// AccentLight color: primaryColor (boosted saturation)
// CardBase tint: primaryColor at 10% opacity
```

### Template 2: Book Stack Card

**Spline Scene Structure**:
```
Scene Root
├── Background (dark, starry)
├── Spotlight (rotating)
└── GyroGroup
    ├── Book1 (top of stack)
    ├── Book2
    ├── Book3
    ├── Book4
    └── Book5 (base of stack)
```

**Dynamic Textures**:
```swift
// If SplineRuntime supports dynamic texture loading:
for (index, book) in topBooks.enumerated() {
    if let bookObject = splineController.findObject(name: "Book\(index + 1)") {
        // Load book cover image
        let coverImage = await loadCover(for: book)
        // Apply as texture (check SplineRuntime API)
        bookObject.applyTexture(coverImage)
    }
}
```

### Template 3: Achievement Constellation

**Spline Scene Structure**:
```
Scene Root
├── SpaceBackground (dark blue gradient)
└── GyroGroup
    ├── Badge_50Books (gold, Z: 200)
    ├── Badge_1000Pages (silver, Z: 100)
    ├── Badge_30DayStreak (bronze, Z: 0)
    ├── Badge_10Genres (silver, Z: -100)
    └── ParticleStars (ambient)
```

---

## Part 6: Integration Checklist

### Phase 1: Setup (Day 1)
- [ ] Add SplineRuntime package to Epilogue
- [ ] Create `MotionManager.swift`
- [ ] Create `SplineLibraryCardView.swift`
- [ ] Test with sample Spline scene (use gyro-spline example)

### Phase 2: Design in Spline (Days 2-3)
- [ ] Create account at spline.design
- [ ] Design glass library card template
- [ ] Export as `.splineswift` (cloud URL or bundle)
- [ ] Test loading in Epilogue

### Phase 3: Gyro Integration (Day 4)
- [ ] Ensure "GyroGroup" named correctly in Spline
- [ ] Test gyroscope on physical device
- [ ] Adjust smoothing factor for feel
- [ ] Fine-tune rotation range

### Phase 4: Data Integration (Days 5-6)
- [ ] Create `ReadingStats` model
- [ ] Calculate year-end stats from existing data
- [ ] Either: Update Spline text objects programmatically
- [ ] Or: Overlay SwiftUI text on Spline scene
- [ ] Apply book colors to Spline materials

### Phase 5: Polish (Days 7-8)
- [ ] Add loading states
- [ ] Optimize performance (reduce poly count)
- [ ] Create 3-5 card variations
- [ ] Add share sheet for exporting card
- [ ] Test on multiple devices (iPhone sizes)

### Phase 6: Launch
- [ ] Add to year-end review flow
- [ ] Analytics tracking
- [ ] Beta test with users
- [ ] Ship! 🚀

---

## Part 7: Advanced: Dynamic Color Application

Integrate Epilogue's existing color extraction with Spline:

```swift
// Pseudocode - adapt to SplineRuntime API capabilities

class SplineColorAdapter {
    static func applyBookColors(
        to controller: SplineController,
        palette: ColorPalette // Your existing type
    ) {
        // Update gradient background
        if let background = controller.findObject(name: "Background") {
            // If Spline supports dynamic material updates:
            background.material.gradientStart = palette.primary.uiColor
            background.material.gradientEnd = palette.secondary.uiColor
        }

        // Update accent light
        if let light = controller.findObject(name: "AccentLight") {
            light.color = palette.accent.uiColor
        }

        // Tint glass card
        if let card = controller.findObject(name: "CardBase") {
            card.material.tint = palette.primary.uiColor.withAlphaComponent(0.1)
        }
    }
}
```

---

## Part 8: Export & Share

### Share as Video

```swift
import AVFoundation

extension SplineLibraryCardView {
    func exportAsVideo(completion: @escaping (URL?) -> Void) {
        // Option 1: Screen recording approach
        // Use ReplayKit to record the Spline view

        // Option 2: Spline native export
        // Check if SplineRuntime supports video export

        // Option 3: Pre-rendered
        // Export video from Spline web → bundle in app
    }
}
```

### Share Card Flow

```swift
struct YearEndShareSheet: View {
    let stats: ReadingStats
    @State private var showingShareSheet = false

    var body: some View {
        VStack {
            YearEndReviewCardView(stats: stats, cardStyle: .glassCard)

            Button("Share Your Year in Reading") {
                showingShareSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .sheet(isPresented: $showingShareSheet) {
            // Standard iOS share sheet
            ShareSheet(items: [generateShareImage()])
        }
    }

    func generateShareImage() -> UIImage {
        // Render current view to image
        // Or use pre-rendered Spline export
    }
}
```

---

## Part 9: Troubleshooting

### Issue: Gyroscope Not Working
```
✓ Check: Testing on physical device? (Simulator has no sensors)
✓ Check: MotionManager.startTracking() called?
✓ Check: Object name in Spline matches code ("GyroGroup")?
✓ Check: Console for warnings about accelerometer availability
```

### Issue: Spline Scene Not Loading
```
✓ Check: URL is correct and reachable
✓ Check: .splineswift file added to Xcode target
✓ Check: SplineRuntime package properly linked
✓ Check: Scene exported with "SwiftUI" format (not Web)
```

### Issue: Jerky Motion
```
✓ Lower smoothing factor (try 0.05)
✓ Increase accelerometer update interval (lower FPS)
✓ Reduce Spline scene complexity (polygon count)
```

### Issue: Scene Too Dark/Bright
```
✓ Adjust ambient light intensity in Spline
✓ Check environment HDRI setting
✓ Ensure phone brightness is up
✓ Test in different lighting conditions
```

---

## Part 10: Next Steps & Ideas

### Expand the Card Collection
- **Monthly reading cards** (not just year-end)
- **Genre-specific cards** (fantasy card = mystical theme)
- **Milestone cards** (100th book, 10,000 pages)

### Interactive Features
- **Tap to flip** card (reveal back with more stats)
- **Swipe through** multiple card styles
- **AR mode** using ARKit (place card in real world)

### Social Features
- **Compare with friends** (side-by-side cards)
- **Challenge cards** ("You read 20% more than last year!")
- **Leaderboards** (most creative card design)

### Gamification
- **Unlock card styles** through achievements
- **Customize materials** (gold vs. silver glass)
- **Animated badges** that pulse when earned

---

## Resources

### Official Documentation
- **Spline Docs**: [docs.spline.design](https://docs.spline.design)
- **Spline iOS SDK**: [docs.spline.design/exporting-your-scene/apple-platform/code-api-for-swift-ui](https://docs.spline.design/exporting-your-scene/apple-platform/code-api-for-swift-ui)
- **CoreMotion**: [developer.apple.com/documentation/coremotion](https://developer.apple.com/documentation/coremotion)

### Inspiration
- **Gábor Pribék**: [@gaborpribek](https://x.com/gaborpribek) - Original inspiration
- **gyro-spline repo**: [github.com/kapor00/gyro-spline](https://github.com/kapor00/gyro-spline)

### Community
- **Spline Discord**: Join for help and inspiration
- **Spline Community**: [community.spline.design](https://community.spline.design)

---

## Summary

You now have everything you need to create beautiful, interactive 3D library cards for Epilogue:

1. ✅ **Design templates** for 3 card styles in Spline
2. ✅ **iOS integration code** using SplineRuntime
3. ✅ **Gyroscope controls** for immersive interaction
4. ✅ **Color extraction integration** with your existing system
5. ✅ **Performance optimization** guidelines
6. ✅ **Step-by-step implementation** checklist

**Start with**: Design one simple glass card in Spline → Export → Integrate → Test gyro → Iterate!

The gyro effect will make these cards feel magical - users will love tilting their device to see their reading stats come to life in 3D. Perfect for year-end sharing on social media.

---

**Questions?** Open an issue or refer back to the gyro-spline repository for working examples.

Good luck! 📚✨📱
