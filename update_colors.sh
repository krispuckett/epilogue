#!/bin/bash

# Update script to replace hardcoded colors with DesignSystem references

echo "Starting color replacement across the codebase..."

# List of files to update
FILES=(
    "ContentView.swift"
    "Views/Library/LibraryView.swift"
    "Views/Library/BookDetailView.swift"
    "Views/Notes/CleanNotesView.swift"
    "Views/Chat/ChatSessionsViewRefined.swift"
    "Views/Settings/SettingsView.swift"
    "Views/Components/LibraryCommandPalette.swift"
    "Views/Components/EnhancedQuickActionsBar.swift"
    "Views/Components/UniversalInputBar.swift"
    "Views/Chat/UnifiedChatView.swift"
    "Views/Library/BookCard.swift"
    "Views/Library/BookSearchSheet.swift"
    "Views/Library/BookCompletionSheet.swift"
    "Views/Library/EditBookSheet.swift"
    "Views/Ambient/AmbientModeView.swift"
)

# Base directory
BASE_DIR="/Users/kris/Epilogue/Epilogue/Epilogue"

for file in "${FILES[@]}"; do
    FULL_PATH="$BASE_DIR/$file"
    if [ -f "$FULL_PATH" ]; then
        echo "Updating $file..."
        
        # Create backup
        cp "$FULL_PATH" "$FULL_PATH.backup"
        
        # Replace the color values
        sed -i '' 's/Color(red: 1\.0, green: 0\.55, blue: 0\.26)/DesignSystem.Colors.primaryAccent/g' "$FULL_PATH"
        sed -i '' 's/Color(red: 0\.11, green: 0\.105, blue: 0\.102)/DesignSystem.Colors.surfaceBackground/g' "$FULL_PATH"
        sed -i '' 's/\.white\.opacity(0\.7)/DesignSystem.Colors.textSecondary/g' "$FULL_PATH"
        sed -i '' 's/\.white\.opacity(0\.5)/DesignSystem.Colors.textTertiary/g' "$FULL_PATH"
        sed -i '' 's/\.white\.opacity(0\.3)/DesignSystem.Colors.textQuaternary/g' "$FULL_PATH"
        
        # Update opacity values to standard increments
        sed -i '' 's/\.opacity(0\.03)/\.opacity(0.05)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.04)/\.opacity(0.05)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.06)/\.opacity(0.05)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.08)/\.opacity(0.10)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.12)/\.opacity(0.10)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.14)/\.opacity(0.15)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.18)/\.opacity(0.20)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.22)/\.opacity(0.20)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.24)/\.opacity(0.25)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.28)/\.opacity(0.30)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.32)/\.opacity(0.30)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.38)/\.opacity(0.40)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.42)/\.opacity(0.40)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.48)/\.opacity(0.50)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.52)/\.opacity(0.50)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.58)/\.opacity(0.60)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.62)/\.opacity(0.60)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.68)/\.opacity(0.70)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.72)/\.opacity(0.70)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.78)/\.opacity(0.80)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.82)/\.opacity(0.80)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.88)/\.opacity(0.90)/g' "$FULL_PATH"
        sed -i '' 's/\.opacity(0\.92)/\.opacity(0.90)/g' "$FULL_PATH"
        
        echo "✓ Updated $file"
    else
        echo "⚠ File not found: $file"
    fi
done

echo "Color replacement complete! Remember to add 'import DesignSystem' to updated files."