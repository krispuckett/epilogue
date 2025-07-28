Working on Epilogue at /Users/kris/Epilogue. 
Current state: ColorCube extraction working, gradients need refinement.
DO NOT modify .pbxproj files.
Test changes incrementally.
The app uses iOS 26 Liquid Glass - NO .background() before .glassEffect()
# Epilogue Project Rules for Claude Code

1. NEVER modify .pbxproj files
2. iOS 26 Glass Effects: NO .background() before .glassEffect()
3. Test after EVERY change
4. ColorCube extraction is working - don't rewrite it
5. Gradient system uses enhanceColor like ambient chat
6. Commit message format: "Fix: [what was fixed]

Critical Project Rules
1. NEVER Modify These Files

.pbxproj files - Let Xcode handle project configuration
Info.plist - Unless specifically needed
Any file in .git directory
SwiftData model files without explicit instruction

2. iOS 26 Liquid Glass Requirements
swift// ❌ NEVER DO THIS - Breaks glass effects completely
.background(Color.white.opacity(0.1))
.glassEffect()

// ✅ ALWAYS DO THIS
.glassEffect()  // Apply directly with NO background modifiers
3. Current System Architecture
Color Extraction (WORKING - Don't Rewrite!)

Location: Epilogue/Core/Colors/OKLABColorExtractor.swift
Method: ColorCube 3D histogram with edge detection
Status: ✅ Correctly extracts colors for most books
Known Issues:

Silmarillion shows green instead of blue (sorting issue)
Love Wins shows red instead of blue (sorting issue)



Gradient System

Location: Epilogue/Core/Background/BookAtmosphericGradientView.swift
Style: Matches ambient chat view (enhanced colors, not desaturated)
Key Function: enhanceColor() - boosts saturation and brightness

Image Loading

Async processing to prevent UI freezing
Downsampling to 400px max for performance
Progressive loading planned but not yet implemented

Safe Modification Guidelines
Before Any Changes

Understand the current implementation
Ask to see the existing code first
Make small, incremental changes
Test after each modification

When Modifying Color Extraction
"I need to modify color extraction in OKLABColorExtractor.swift
Current issue: [describe specific problem]
Desired outcome: [what should happen]
Please show me the current implementation first."
When Modifying Gradients
"I need to adjust gradients in BookAtmosphericGradientView.swift
Current: [describe current appearance]  
Goal: [describe desired appearance]
Keep the enhanceColor approach from ambient chat."
Testing Requirements
After Every Change

Clean build folder (Cmd+Shift+K)
Build and run (Cmd+R)
Test these specific books:

Lord of the Rings (should show red + gold)
The Odyssey (should show teal)
The Silmarillion (currently green, should be blue)
Love Wins (currently red, should be blue)



Console Output to Verify
🎨 ColorCube Extraction for [Book Name]
📊 Found X distinct color peaks
✅ Final ColorCube Palette:
  Primary: RGB(X, X, X)
  Secondary: RGB(X, X, X)
Common Pitfalls to Avoid
1. Over-Engineering Solutions

Current system works well, just needs refinement
Don't rewrite working code
Focus on specific issues

2. Breaking Glass Effects

Any .background() modifier before .glassEffect() breaks it
This includes clear backgrounds, opacity, everything

3. Performance Issues

Always downsample images before processing
Use async/await for heavy operations
Don't process on main thread

4. Color Extraction "Fixes" That Break Things

The extraction FINDS the right colors
The issue is usually role assignment (which color becomes primary)
Don't change the extraction algorithm without understanding it

Current State Summary
✅ Working

ColorCube extraction finds correct colors
Async processing prevents freezing
Lord of the Rings shows red + gold
The Odyssey shows teal
Gradients use ambient chat style (enhanced, vibrant)

🔧 Needs Fixes

Silmarillion: Shows green instead of blue (role assignment)
Love Wins: Shows red instead of blue (role assignment)
Progressive loading not yet implemented
Some edge cases in color priority

📋 Planned Improvements

Progressive image loading (low res → high res)
Better role assignment for non-dark covers
Caching system for color palettes
Debug view for color extraction

Session Starting Template
Use this when starting a Claude Code session:
Working on Epilogue iOS app at /Users/kris/Epilogue

Current context:
- iOS 26 with Liquid Glass (NO backgrounds before glass effects)
- ColorCube extraction working well
- Gradient system uses enhanceColor() like ambient chat
- Need to fix: [specific issue]

Rules:
- Don't modify .pbxproj files
- Make incremental changes
- Test after each change
- Show me the code before applying changes

Task: [specific task description]
Git Safety Commands
Before Claude Code Session
bashgit add .
git commit -m "WIP: Pre-Claude Code checkpoint"
git push origin main
After Successful Changes
bashgit add [specific files]
git commit -m "Fix: [what was fixed]"
git push origin main
If Things Break
bash# See what changed
git status
git diff

# Undo everything
git reset --hard HEAD

# Or restore specific file
git checkout origin/main -- path/to/broken/file.swift
Emergency Recovery
If Claude Code severely breaks the project:

Don't Panic - Everything is in Git
Check GitHub - Your last push is safe there
Nuclear Option:
bashcd ~/Desktop
git clone https://github.com/krispuckett/epilogue epilogue-fresh

Cherry Pick - Copy over only the working changes
