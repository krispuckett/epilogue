# Metal Shader Setup Instructions

## Files Created:
1. **MetalLiteraryView.swift** - The Metal view implementation
2. **LiteraryCompanion.metal** - The GPU shader code

## Setup Steps:

### 1. Add Metal Shader to Build Phase
**IMPORTANT**: The .metal file needs to be added to the "Compile Sources" build phase:

1. Open `Epilogue.xcodeproj` in Xcode
2. Select the Epilogue project in the navigator
3. Select the "Epilogue" target
4. Go to "Build Phases" tab
5. Expand "Compile Sources"
6. Click the "+" button
7. Add `LiteraryCompanion.metal`
8. Make sure it's in the list with all other source files

### 2. Verify Metal Framework
Metal framework should be automatically linked in iOS, but verify:
- In "Build Phases" → "Link Binary With Libraries"
- Metal.framework should be present (it's usually automatic)

### 3. Test the Implementation
1. Run the app in simulator or device
2. Navigate to the Chat tab
3. The empty state should show the Metal particle system

## Troubleshooting:

### If Metal shader doesn't compile:
- Check that the .metal file is in "Compile Sources"
- Look for shader compilation errors in Xcode's build log
- Make sure the Metal function names match between Swift and Metal files

### If app crashes:
- The code includes fallback to SwiftUI animation if Metal isn't available
- Check console for error messages about Metal initialization
- Simulator should support Metal, but some older devices might not

### Performance Notes:
- 5000 particles running at 60 FPS
- Each particle has physics simulation
- Warm literary colors with dynamic sizing
- Gravity wells create book-like attraction points

## Current Implementation Features:
- Turbulent flow fields using noise functions
- Curl noise for organic particle movement
- Heat-based coloring system
- Dynamic particle sizing based on properties
- Smooth respawning when particles exit screen
- Literary theme with warm amber/gold colors