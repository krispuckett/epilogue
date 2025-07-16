# Quote Parsing Flow Debug

## Test Input
`"Remember to live." Seneca, On the Shortness of Life, pg 30`

## Expected Flow

### 1. User Types Quote in NotesView
- Opens EditNoteSheet with empty note
- Types the quote in InlineTokenEditor

### 2. InlineTokenEditor Detection
- Detects quote pattern
- Calls `CommandParser.parseQuote()`
- Gets back: 
  - content: "Remember to live."
  - author: "Seneca|||BOOK|||On the Shortness of Life|||PAGE|||pg 30"
- Reformats to:
  ```
  Remember to live.

  — Seneca
  On the Shortness of Life
  pg 30
  ```

### 3. Save Button Pressed
- `saveNote()` is called
- `parseFullText()` is called with the formatted text
- Should extract:
  - content: "Remember to live."
  - author: "Seneca"
  - bookTitle: "On the Shortness of Life"
  - pageNumber: 30

### 4. Note Created
- Note object should have:
  ```swift
  Note(
    type: .quote,
    content: "Remember to live.",
    author: "Seneca",
    bookTitle: "On the Shortness of Life",
    pageNumber: 30
  )
  ```

### 5. QuoteCard Display
- Shows large amber quote
- Text: "Remember to live." (no quotes)
- Author: SENECA
- Book: ON THE SHORTNESS OF LIFE
- Page: PAGE 30

## Potential Issues
1. The formatted text might not have the exact pattern parseFullText expects
2. The page extraction regex might not match "pg 30"
3. The author/book/page might all be getting stored in content field