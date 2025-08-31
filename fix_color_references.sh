#!/bin/bash

# Fix incorrect ColorDesignSystem references
echo "Fixing incorrect ColorDesignSystem references..."

# Base directory
BASE_DIR="/Users/kris/Epilogue/Epilogue/Epilogue"

# Find and replace ColorDesignSystem with DesignSystem
find "$BASE_DIR" -name "*.swift" -type f -exec sed -i '' 's/ColorDesignSystem\.Colors/DesignSystem.Colors/g' {} \;

echo "✓ Fixed all ColorDesignSystem references"