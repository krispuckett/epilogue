# Quote Formatting Fix - Testing Instructions

## What Was Fixed
The quote cards now match the exact design from the reference image:
- Large decorative opening quote mark (60pt amber)
- Quote text WITHOUT quotation marks (implied by the design)
- Author in uppercase with proper spacing
- Book title on separate line
- Clean white background with subtle shadow

## Changes Made
1. **QuoteCard** - Completely refactored to match reference design:
   - Removed quotation marks from text display
   - Adjusted typography and spacing
   - White background instead of cream
   - Proper shadow and corner radius
2. **Quote Parsing** - Automatically removes quotation marks from content
3. **EditNoteSheet** - Strips quotes when saving/displaying
4. **InlineTokenEditor** - Reformats quotes without quotation marks
5. **UniversalCommandBar** - Removes quotes before passing to editor

## Test Cases

### Test 1: Command Bar Quote with Author + Book
1. Tap the + button to expand command bar
2. Type: `"Everything is meaningless" - the Teacher, Ecclesiastes`
3. The quote sheet should appear with the text properly formatted
4. Save and verify the quote card shows:
   - Quote text with smart quotes
   - Author: "THE TEACHER" (uppercase)
   - Book: "ECCLESIASTES" (uppercase, smaller font)

### Test 2: Notes View Quote with Author + Book
1. Go to Notes tab
2. Tap the + button in header
3. Type: `"To be or not to be" - Hamlet, Shakespeare`
4. The system should auto-detect it as a quote
5. The text should reformat to show book on separate line
6. Save and verify proper display

### Test 3: Simple Quote (No Book)
1. Type: `"The only way out is through" - Robert Frost`
2. Should display with just author, no book line

### Test 4: Quote with Page Number
1. Type: `"All animals are equal" - George Orwell, Animal Farm, p. 42`
2. Should display:
   - Quote text
   - Author: GEORGE ORWELL
   - Book: ANIMAL FARM
   - Page: PAGE 42

## Visual Reference
Quote cards should match the design with:
- Large decorative opening quote mark (80pt Georgia)
- Quote text in 24pt Georgia
- Author in 14pt uppercase with 2.0 kerning
- Book title in 11pt uppercase with 1.5 kerning
- Warm cream background (#FAF8F5)