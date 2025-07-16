# Perfect Quote Formatting - Test Guide

## The Goal
Make ALL quotes look exactly like the reference design:
- Large amber opening quote mark (60pt)
- Quote text in Georgia 24pt WITHOUT quotation marks
- Author in uppercase with proper kerning
- Book title in uppercase below author
- Page number if provided
- Clean white card background

## Supported Input Formats

### Format 1: Quote with Author
```
"In three words I can sum up everything I've learned about life: it goes on." - Robert Frost
```
Result:
- Quote: In three words I can sum up everything I've learned about life: it goes on.
- Author: ROBERT FROST

### Format 2: Quote with Author and Book
```
"It is during our darkest moments that we must focus to see the light." - Aristotle, The Collected Wisdom
```
Result:
- Quote: It is during our darkest moments that we must focus to see the light.
- Author: ARISTOTLE
- Book: THE COLLECTED WISDOM

### Format 3: Quote with Author, Book, and Page
```
"Everything is meaningless" - the Teacher, Ecclesiastes, p. 47
```
Result:
- Quote: Everything is meaningless
- Author: THE TEACHER
- Book: ECCLESIASTES
- Page: PAGE 47

### Format 4: Alternative Page Formats
All these work:
- `p. 47`
- `page 47`
- `pg 47`
- `47` (if it's the third comma-separated item)

## Test Cases

### Test 1: Command Bar Entry
1. Tap + to open command bar
2. Type: `"Life is long if you know how to use it" - Seneca, On the Shortness of Life`
3. The quote editor should show the properly formatted text
4. Save and verify the QuoteCard displays correctly

### Test 2: Notes View Entry
1. Go to Notes tab
2. Tap + in header
3. Type: `"The only way out is through" - Robert Frost, Selected Poems, p. 156`
4. System should auto-detect as quote
5. Save and verify all fields display correctly

### Test 3: Complex Book Titles
1. Type: `"To be or not to be" - Shakespeare, Hamlet, Prince of Denmark, Act 3`
2. Should parse correctly (book title can have commas if no page number follows)

## What Happens Behind the Scenes
1. **Quote Detection**: System detects quote pattern with quotation marks
2. **Auto-Stripping**: Quotation marks are removed (the large quote mark implies them)
3. **Attribution Parsing**: Author, book, and page are extracted
4. **Formatting**: Text is reformatted with proper line breaks
5. **Display**: QuoteCard renders with perfect typography

## Visual Checklist
✓ Large amber quote mark at top left (60pt Georgia)
✓ Drop cap for first letter (72pt Georgia)
✓ Quote text has NO quotation marks
✓ Text is black on white background
✓ Author is uppercase with 2.0 letter spacing
✓ Book title is uppercase with 1.5 letter spacing
✓ Page number shows as "PAGE 123"
✓ Card has subtle shadow and rounded corners
✓ 32pt padding inside the card

## Drop Cap Example
For the quote "In three words I can sum up everything I've learned about life: it goes on."
- The "I" would be displayed as a large 72pt drop cap
- The rest "n three words..." continues at normal 24pt size