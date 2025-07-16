# Testing Smart Quote Detection

## Test 1: Command Bar Quote Format
1. Tap the + button to expand command bar
2. Type: `"The only way out is through" - Robert Frost`
3. Should automatically detect as quote type
4. EditNoteSheet should show:
   - Quote type selected (purple icon)
   - Content: The only way out is through
   - Author token: Robert Frost

## Test 2: Notes View Quote Format
1. Go to Notes tab
2. Tap the + button in header
3. In the text field, type: `"Be yourself; everyone else is already taken" - Oscar Wilde`
4. Should automatically switch to quote type
5. Save and verify it creates a quote card

## Test 3: Smart Quote Variations
Test these formats:
- `"Simple quote"` → Should detect as quote
- `"Quote with author" - Author Name` → Quote with attribution
- `"Quote" – Em dash Author` → Should handle em dash
- `"Quote" — Long dash Author` → Should handle long dash

## Test 4: Regular Note (No Quote Detection)
1. Type: `Remember to test the app`
2. Should remain as a note type
3. No quote detection should occur

## What's New:
- CommandParser now detects quote formats
- Enhanced quote pattern matching for "content" - author
- EditNoteSheet auto-detects quotes when creating new notes
- Supports straight quotes (") and smart quotes (")
- Parses author attribution automatically