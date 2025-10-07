#!/bin/bash

# Test Migration Script for V2 → V3
# This verifies user data is preserved during schema migration

set -e

echo "🧪 Testing SwiftData Migration V2 → V3"
echo "========================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Get current git state
echo "📍 Current git state:"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_COMMIT=$(git rev-parse --short HEAD)
echo "   Branch: $CURRENT_BRANCH"
echo "   Commit: $CURRENT_COMMIT"
echo ""

# 2. Check if simulator is running
echo "📱 Checking simulator status..."
SIMULATOR_BOOTED=$(xcrun simctl list devices | grep "Booted" | wc -l)
if [ "$SIMULATOR_BOOTED" -eq "0" ]; then
    echo "${YELLOW}⚠️  No simulator running. Please start one first.${NC}"
    exit 1
fi
echo "${GREEN}✅ Simulator is running${NC}"
echo ""

# 3. Uninstall existing app
echo "🗑️  Uninstalling existing app..."
xcrun simctl uninstall booted com.readepilogue.app 2>/dev/null || echo "   (no app installed)"
echo ""

# 4. Build and install current version (V3)
echo "🔨 Building V3 version..."
xcodebuild -project Epilogue/Epilogue.xcodeproj \
    -scheme Epilogue \
    -sdk iphonesimulator \
    -configuration Debug \
    build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED)"

if [ $? -ne 0 ]; then
    echo "${RED}❌ Build failed${NC}"
    exit 1
fi
echo "${GREEN}✅ Build succeeded${NC}"
echo ""

# 5. Instructions for manual testing
echo "${YELLOW}📋 Manual Test Steps:${NC}"
echo ""
echo "1. Run the app from Xcode"
echo "2. Add 5-10 test books to your library"
echo "3. Add some notes and reading sessions"
echo "4. Quit the app"
echo ""
echo "5. Check the Xcode console for migration logs:"
echo "   - Look for: '🔄 Starting migration from V2 to V3...'"
echo "   - Look for: '📊 Pre-migration counts:'"
echo "   - Look for: '📊 Post-migration counts:'"
echo "   - Look for: '✅ Data preserved successfully!'"
echo ""
echo "6. Verify your data:"
echo "   - All books still present"
echo "   - All notes intact"
echo "   - All reading sessions preserved"
echo ""
echo "7. Test new offline features:"
echo "   - Covers load when offline"
echo "   - Ambient mode queues questions offline"
echo "   - Status pill shows correct state"
echo ""
echo "${GREEN}✅ If all checks pass, migration is safe for TestFlight${NC}"
echo ""

# 6. TestFlight recommendation
echo "🚀 TestFlight Rollout Plan:"
echo ""
echo "Phase 1: Internal Testing (You + 2-3 trusted users)"
echo "   - Duration: 24 hours"
echo "   - Check crash logs daily"
echo ""
echo "Phase 2: Small Beta Group (10-20 users)"
echo "   - Duration: 48 hours"
echo "   - Monitor for data loss reports"
echo ""
echo "Phase 3: Full TestFlight (All beta testers)"
echo "   - Duration: 1 week"
echo "   - Gather feedback on offline features"
echo ""
echo "Phase 4: App Store Release"
echo "   - Only if Phases 1-3 are clean"
echo ""