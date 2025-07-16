# Testing Instructions - Saving Quotes & Notes

## Test 1: Save a Quote via Command Bar
1. Tap the + button to expand the command bar
2. Type: `quote: "The only way out is through" - Robert Frost`
3. The EditNoteSheet should appear with:
   - Quote type selected
   - Content pre-filled
   - Inline token editing enabled
4. Save the quote
5. Verify it appears in the Notes tab

## Test 2: Save a Note via Command Bar  
1. Tap the + button to expand the command bar
2. Type: `note: Remember to test the persistence`
3. The EditNoteSheet should appear with:
   - Note type selected
   - Content pre-filled
4. Save the note
5. Verify it appears in the Notes tab

## Test 3: Add Quote from Notes View
1. Go to Notes tab
2. Tap the + button in the header
3. The EditNoteSheet should appear
4. Switch to Quote type
5. Add content with tokens
6. Save and verify

## What Changed:
- Updated `NotesView` to use `EditNoteSheet` instead of `AddNoteSheet`
- Updated `UniversalCommandBar` to use `EditNoteSheet` for both notes and quotes
- Changed presentation background from `.clear` to `.regularMaterial` to fix the weird background issue
- All sheet presentations now consistently use the same editor component

## Expected Results:
✅ Quotes and notes should save properly
✅ Background should look clean (no weird artifacts)
✅ Inline token editing should work as designed
✅ Data should persist between app launches