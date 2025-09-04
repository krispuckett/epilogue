#!/bin/bash

# Test script for BookSearchSheet autofill functionality
echo "📱 Testing BookSearchSheet Autofill..."
echo "=================================="
echo ""
echo "Please manually test the following in the running app:"
echo ""
echo "1. Open the liquid command palette (swipe down or use keyboard shortcut)"
echo "2. Type a book name like 'Harry Potter' or 'Lord of the Rings'"
echo "3. Press Enter or tap the search button"
echo ""
echo "Expected behavior:"
echo "✅ BookSearchSheet should open"
echo "✅ The search query should be pre-filled in the search bar"
echo "✅ The search should automatically execute"
echo "✅ Book results should appear without manual interaction"
echo ""
echo "If the search is NOT auto-executing, check the console logs for:"
echo "📚 BookSearchSheet appeared with query:"
echo "🔍 Starting search for:"
echo "📖 Found X results for:"
echo ""
echo "Console output will appear below:"
echo "=================================="

# Monitor console logs for our debug messages
xcrun simctl spawn booted log stream --level debug 2>/dev/null | grep -E "📚|🔍|📖|📝|🔤|❌" 