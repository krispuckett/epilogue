# Xcode Project Fix Instructions

## Issue: Duplicate OKLABColorExtractor.swift References

The Xcode project has two references to OKLABColorExtractor.swift:
1. One in `Core/Colors/` (correct location)
2. One in `Views/Core/` (duplicate - file has been deleted)

## Fix in Xcode:

1. Open Epilogue.xcodeproj in Xcode
2. In the Project Navigator, you'll see two OKLABColorExtractor.swift files (one will be red/missing)
3. Right-click on the red/missing one and select "Delete"
4. Choose "Remove Reference" (not "Move to Trash")
5. Clean build folder: Product → Clean Build Folder (Shift+Cmd+K)
6. Build and run

## Alternative Fix (Manual):

If the above doesn't work, you can manually edit the project.pbxproj file:
1. Close Xcode
2. Open project.pbxproj in a text editor
3. Remove these lines:
   - Line containing: `01190E3D2E3077480021AFAA /* OKLABColorExtractor.swift in Sources */`
   - Line containing: `01190E3C2E3077480021AFAA /* OKLABColorExtractor.swift */ = {isa = PBXFileReference;`
   - The reference to `01190E3C2E3077480021AFAA` in the Core group
4. Save and reopen Xcode

The color extraction should now work properly with HTTPS URLs!