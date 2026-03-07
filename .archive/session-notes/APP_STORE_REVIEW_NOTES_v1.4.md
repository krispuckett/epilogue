# App Store Review Notes - Epilogue v1.5

## Bug Fix Release

**What's Fixed**: Book search filtering now properly includes self-published books and ranks exact matches first.

---

## NO LOGIN REQUIRED
Works immediately upon launch. No account or setup needed.

---

## 3-Minute Test

1. Tap **+** button → Search for "The Nightbird's Feather"
2. Verify book appears in results (previously filtered out)
3. Search for "Meditations Marcus Aurelius"
4. Verify exact match appears at top of results

---

## Technical Changes

- Relaxed quality filtering to include self-published books
- Enhanced exact title matching (+300 score boost)
- Removed "illustrated" penalty that blocked legitimate books
- Added self-published publisher detection
- Increased author match scoring (+150 boost)

All changes confined to `EnhancedGoogleBooksService.swift` - no other functionality affected.

---

**Privacy**: https://readepilogue.com/privacy
**Support**: support@readepilogue.com

Thank you for reviewing Epilogue v1.5!
