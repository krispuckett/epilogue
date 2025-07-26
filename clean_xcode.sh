#!/bin/bash

echo "🧹 Cleaning Xcode build artifacts..."

# Clean DerivedData
echo "Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Epilogue-*

# Clean local build
echo "Removing local build directory..."
rm -rf .build
rm -rf DerivedData

# Clean user data
echo "Removing xcuserdata..."
find . -name "xcuserdata" -type d -exec rm -rf {} + 2>/dev/null

# Clean module cache
echo "Cleaning module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

echo "✅ Cleanup complete!"
echo ""
echo "Now in Xcode:"
echo "1. Close the project"
echo "2. Quit Xcode completely"
echo "3. Open the project again"
echo "4. Clean Build Folder (Cmd+Shift+K)"
echo "5. Build (Cmd+B)"