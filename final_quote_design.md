# Final Quote Card Design - Exact Specifications

## Visual Design Elements

### 1. Opening Quote Mark
- Smart quote character (" not ")
- 80pt Georgia font
- Amber color with 68% opacity
- Offset: x: -10, y: 20
- Zero frame height (overlaps content)

### 2. Drop Cap
- First letter of quote
- 56pt Georgia font
- Dark text color (#1C1B1A)
- 4pt trailing padding
- Offset y: -8

### 3. Quote Text
- Remaining text after first letter
- 24pt Georgia font
- Dark text color (#1C1B1A)
- Line spacing: 11pt (1.5x line height)
- Top padding: 8pt

### 4. Gradient Divider
- Horizontal rule with gradient
- Height: 0.5pt
- Gradient: 10% opacity → 100% opacity → 10% opacity
- Top padding: 20pt

### 5. Attribution Section
- Monospaced font (SF Mono)
- Hierarchical opacity and sizing:
  - Author: 13pt, medium weight, 80% opacity, 1.5 kerning
  - Book: 11pt, regular weight, 60% opacity, 1.2 kerning  
  - Page: 10pt, regular weight, 50% opacity, 1.0 kerning
- 6pt spacing between elements

### 6. Card Styling
- Background: Warm cream (#FAF8F5)
- Corner radius: 12pt
- Padding: 32pt all around
- Shadow: Subtle warm shadow
- Press animation: Scale to 98%

## Quote Parsing Requirements

When user types: `"Remember to live." Seneca, On the Shortness of Life, pg 30`

The system must:
1. Detect quote pattern
2. Remove quotation marks from content
3. Parse into fields:
   - content: "Remember to live."
   - author: "Seneca"
   - bookTitle: "On the Shortness of Life"
   - pageNumber: 30

## Typography Hierarchy
1. Smart quote: Largest (80pt), amber, decorative
2. Drop cap: Large (56pt), emphasis on first letter
3. Body text: Readable (24pt), generous line spacing
4. Attribution: Small (10-13pt), monospaced, decreasing opacity

This creates a beautiful literary design that honors the quote while maintaining excellent readability.