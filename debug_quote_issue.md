# Debug: Quote Display Issue

## Problem
When typing: `"Remember to live." Seneca, On the Shortness of Life, pg 30`

The quote card shows:
```
"Remember to live" Seneca, On Shortness of Life
PAGE 30
```

But it SHOULD show:
```
[Large amber quote mark]
Remember to live.

SENECA
ON THE SHORTNESS OF LIFE  
PAGE 30
```

## Root Cause Analysis

Looking at the screenshot, I see:
1. The quote still has quotation marks (should be removed)
2. Everything is on fewer lines than expected
3. The formatting doesn't match our QuoteCard design

This suggests the Note object might have:
- content: "Remember to live" Seneca, On Shortness of Life" (all in content field)
- author: nil
- bookTitle: nil  
- pageNumber: 30 (this seems to be working)

## Solution
The issue is likely that when the quote is typed directly in NotesView, the InlineTokenEditor reformats it, but the parseFullText method isn't correctly extracting the author and book from the reformatted text.

The flow should be:
1. Type quote → 2. Detect and reformat → 3. Parse into fields → 4. Display correctly