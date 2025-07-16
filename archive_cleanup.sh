#!/bin/bash

# Create archive directory with timestamp
ARCHIVE_DIR="archive_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$ARCHIVE_DIR"

echo "Creating archive directory: $ARCHIVE_DIR"

# Archive test and experimental glass files
echo "Archiving test and experimental files..."
mkdir -p "$ARCHIVE_DIR/test_files"
mv Epilogue/Views/TestGlassMenu.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/TestLongPress.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/TestGlassOptionsMenu.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/SimpleGlassMenu.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/GlassBlurTest.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/GlassPrinciplesDemo.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/GlassTransitionTest.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/CorrectGlassImplementation.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/GlassMaterialization.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null
mv Epilogue/Views/MaterializeTransition.swift "$ARCHIVE_DIR/test_files/" 2>/dev/null

# Archive obsolete components
echo "Archiving obsolete components..."
mkdir -p "$ARCHIVE_DIR/obsolete_components"
mv Epilogue/Views/UniversalCommandBar.swift "$ARCHIVE_DIR/obsolete_components/" 2>/dev/null
mv Epilogue/Views/NoteComposerView.swift "$ARCHIVE_DIR/obsolete_components/" 2>/dev/null
mv Epilogue/Views/QuickCaptureSheet.swift "$ARCHIVE_DIR/obsolete_components/" 2>/dev/null
mv Epilogue/Views/CommandPalette.swift "$ARCHIVE_DIR/obsolete_components/" 2>/dev/null
mv Epilogue/Views/CommandPaletteView.swift "$ARCHIVE_DIR/obsolete_components/" 2>/dev/null
mv Epilogue/ContentViewTabBased.swift "$ARCHIVE_DIR/obsolete_components/" 2>/dev/null

# Archive GlassEditNoteSheet since we're using LiquidEditSheet now
mv Epilogue/Views/GlassEditNoteSheet.swift "$ARCHIVE_DIR/obsolete_components/" 2>/dev/null

# Archive debug files
echo "Archiving debug files..."
mkdir -p "$ARCHIVE_DIR/debug_files"
mv debug_quote_parsing.swift "$ARCHIVE_DIR/debug_files/" 2>/dev/null
mv test_*.md "$ARCHIVE_DIR/debug_files/" 2>/dev/null
mv debug_*.md "$ARCHIVE_DIR/debug_files/" 2>/dev/null
mv final_quote_design.md "$ARCHIVE_DIR/debug_files/" 2>/dev/null

echo "✅ Archive created at: $ARCHIVE_DIR"
echo ""
echo "Active files remaining:"
echo "- LiquidCommandPalette.swift (main input component)"
echo "- LiquidEditSheet.swift (edit/create notes)"
echo "- GlassOptionsMenu.swift (long press menu)"
echo "- NotesView.swift"
echo "- MainNavigationView.swift"
echo "- LibraryView.swift"
echo "- BookDetailView.swift"
echo "- And other core components"
echo ""
echo "⚠️  Remember to:"
echo "1. Remove references from Xcode project file"
echo "2. Test the app thoroughly after cleanup"
echo "3. Commit changes to git"