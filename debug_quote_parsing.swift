// Debug test for quote parsing

let testQuote = "\"Remember to live.\" Seneca, On the Shortness of Life, pg 30"

// Test the parser
let parsed = CommandParser.parseQuote(testQuote)
print("Content: \(parsed.content)")
print("Author: \(parsed.author ?? "nil")")

// Expected output:
// Content: Remember to live.
// Author: Seneca|||BOOK|||On the Shortness of Life|||PAGE|||pg 30

// The UniversalCommandBar should then split this into:
// authorText: "Seneca"
// bookText: "On the Shortness of Life"  
// pageText: "pg 30"

// And format it as:
// Remember to live.
//
// — Seneca
// On the Shortness of Life
// pg 30

// Which EditNoteSheet.parseFullText should extract as:
// content: "Remember to live."
// author: "Seneca"
// bookTitle: "On the Shortness of Life"
// pageNumber: 30 (extracted from "pg 30")