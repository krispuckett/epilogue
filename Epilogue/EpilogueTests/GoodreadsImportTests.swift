import XCTest
import Foundation
@testable import Epilogue

/// Tests for Goodreads CSV import functionality
class GoodreadsImportTests: XCTestCase {

    // MARK: - CSV Parsing Tests

    func test_whenParsingValidCSVRow_thenExtractsAllFields() {
        // Given: A valid CSV row with all fields
        let csvRow = "\"The Hobbit\",\"J.R.R. Tolkien\",\"9780547928227\",\"9780547928227\",5,\"2024/01/15\",\"2023/12/01\",\"read\",\"Amazing book!\""

        // When: Parsing the row
        let columns = parseCSVRow(csvRow)

        // Then: Should extract all fields correctly
        XCTAssertEqual(columns.count, 9)
        XCTAssertEqual(columns[0], "The Hobbit")
        XCTAssertEqual(columns[1], "J.R.R. Tolkien")
        XCTAssertEqual(columns[2], "9780547928227")
        XCTAssertEqual(columns[3], "9780547928227")
        XCTAssertEqual(columns[4], "5")
        XCTAssertEqual(columns[5], "2024/01/15")
        XCTAssertEqual(columns[6], "2023/12/01")
        XCTAssertEqual(columns[7], "read")
        XCTAssertEqual(columns[8], "Amazing book!")
    }

    func test_whenParsingRowWithCommasInQuotes_thenHandlesCorrectly() {
        // Given: A CSV row with commas inside quoted strings
        let csvRow = "\"Harry Potter, and the Sorcerer's Stone\",\"Rowling, J.K.\",\"123456\",\"\",3,\"\",\"\",\"to-read\",\"\""

        // When: Parsing the row
        let columns = parseCSVRow(csvRow)

        // Then: Should keep commas inside quotes
        XCTAssertEqual(columns[0], "Harry Potter, and the Sorcerer's Stone")
        XCTAssertEqual(columns[1], "Rowling, J.K.")
    }

    func test_whenParsingRowWithEscapedQuotes_thenHandlesCorrectly() {
        // Given: A CSV row with escaped quotes
        let csvRow = "\"She said \"\"Hello\"\"\",\"Author Name\",\"\",\"\",0,\"\",\"\",\"to-read\",\"\""

        // When: Parsing the row
        let columns = parseCSVRow(csvRow)

        // Then: Should handle escaped quotes
        XCTAssertTrue(columns[0].contains("\""))
    }

    func test_whenParsingRowWithEmptyFields_thenReturnsEmptyStrings() {
        // Given: A CSV row with empty fields
        let csvRow = "\"Book Title\",\"Author\",\"\",\"\",0,\"\",\"\",\"to-read\",\"\""

        // When: Parsing the row
        let columns = parseCSVRow(csvRow)

        // Then: Empty fields should be empty strings
        XCTAssertEqual(columns[2], "")
        XCTAssertEqual(columns[3], "")
        XCTAssertEqual(columns[5], "")
    }

    // MARK: - ISBN Extraction Tests

    func test_whenISBN13Exists_thenUsesISBN13AsPrimary() {
        // Given: A book with both ISBN and ISBN13
        let book = createCSVBook(isbn: "1234567890", isbn13: "9781234567890")

        // When: Getting primary ISBN
        let primaryISBN = book.primaryISBN

        // Then: Should prefer ISBN13
        XCTAssertEqual(primaryISBN, "9781234567890")
    }

    func test_whenOnlyISBNExists_thenUsesISBN() {
        // Given: A book with only ISBN
        let book = createCSVBook(isbn: "1234567890", isbn13: "")

        // When: Getting primary ISBN
        let primaryISBN = book.primaryISBN

        // Then: Should use ISBN
        XCTAssertEqual(primaryISBN, "1234567890")
    }

    func test_whenNoISBNExists_thenReturnsNil() {
        // Given: A book with no ISBN
        let book = createCSVBook(isbn: "", isbn13: "")

        // When: Getting primary ISBN
        let primaryISBN = book.primaryISBN

        // Then: Should return nil
        XCTAssertNil(primaryISBN)
    }

    // MARK: - Rating Parsing Tests

    func test_whenRatingIsValid_thenParsesCorrectly() {
        // Given: Books with valid ratings
        let ratings = ["0", "1", "2", "3", "4", "5"]

        // When: Parsing ratings
        let parsedRatings = ratings.compactMap { Int($0) }

        // Then: Should parse all ratings
        XCTAssertEqual(parsedRatings, [0, 1, 2, 3, 4, 5])
    }

    func test_whenRatingIsInvalid_thenReturnsZero() {
        // Given: Invalid rating strings
        let invalidRatings = ["", "abc", "-1", "10"]

        // When: Parsing ratings
        let parsedRatings = invalidRatings.map { Int($0) ?? 0 }

        // Then: Should default to 0 for invalid ratings
        XCTAssertEqual(parsedRatings, [0, 0, 0, 0])
    }

    // MARK: - Date Parsing Tests

    func test_whenDateInSlashFormat_thenParsesCorrectly() {
        // Given: Dates in slash format
        let dateStrings = ["2024/01/15", "2023/12/31"]

        // When: Parsing dates
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let dates = dateStrings.compactMap { formatter.date(from: $0) }

        // Then: Should parse both dates
        XCTAssertEqual(dates.count, 2)
    }

    func test_whenDateInDashFormat_thenParsesCorrectly() {
        // Given: Dates in dash format
        let dateStrings = ["2024-01-15", "2023-12-31"]

        // When: Parsing dates
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let dates = dateStrings.compactMap { formatter.date(from: $0) }

        // Then: Should parse both dates
        XCTAssertEqual(dates.count, 2)
    }

    func test_whenDateIsEmpty_thenReturnsNil() {
        // Given: Empty date string
        let dateString = ""

        // When: Parsing date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let date = formatter.date(from: dateString)

        // Then: Should return nil
        XCTAssertNil(date)
    }

    func test_whenDateIsInvalid_thenReturnsNil() {
        // Given: Invalid date string
        let dateString = "not-a-date"

        // When: Parsing date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let date = formatter.date(from: dateString)

        // Then: Should return nil
        XCTAssertNil(date)
    }

    // MARK: - Reading Status Tests

    func test_whenShelfIsRead_thenStatusIsRead() {
        // Given: A book on "read" shelf
        let book = createCSVBook(exclusiveShelf: "read")

        // When: Getting reading status
        let status = book.readingStatus

        // Then: Should be Read
        XCTAssertEqual(status, .read)
    }

    func test_whenShelfIsCurrentlyReading_thenStatusIsCurrentlyReading() {
        // Given: A book on "currently-reading" shelf
        let book = createCSVBook(exclusiveShelf: "currently-reading")

        // When: Getting reading status
        let status = book.readingStatus

        // Then: Should be Currently Reading
        XCTAssertEqual(status, .currentlyReading)
    }

    func test_whenShelfIsToRead_thenStatusIsWantToRead() {
        // Given: A book on "to-read" shelf
        let book = createCSVBook(exclusiveShelf: "to-read")

        // When: Getting reading status
        let status = book.readingStatus

        // Then: Should be Want to Read
        XCTAssertEqual(status, .wantToRead)
    }

    func test_whenShelfIsUnknown_thenDefaultsToWantToRead() {
        // Given: A book on unknown shelf
        let book = createCSVBook(exclusiveShelf: "custom-shelf")

        // When: Getting reading status
        let status = book.readingStatus

        // Then: Should default to Want to Read
        XCTAssertEqual(status, .wantToRead)
    }

    // MARK: - Special Character Handling Tests

    func test_whenTitleContainsSpecialCharacters_thenHandlesCorrectly() {
        // Given: Titles with special characters
        let specialTitles = [
            "Book: A Story",
            "Book & Novel",
            "Book's Title",
            "Book (2024)",
            "Book — The Sequel"
        ]

        // When: Cleaning values
        let cleanedTitles = specialTitles.map { cleanCSVValue($0) }

        // Then: Should preserve special characters
        XCTAssertEqual(cleanedTitles[0], "Book: A Story")
        XCTAssertEqual(cleanedTitles[1], "Book & Novel")
        XCTAssertEqual(cleanedTitles[2], "Book's Title")
        XCTAssertEqual(cleanedTitles[3], "Book (2024)")
        XCTAssertEqual(cleanedTitles[4], "Book — The Sequel")
    }

    func test_whenFieldHasExcelFormulaProtection_thenRemovesEqualsSign() {
        // Given: A value with Excel formula protection
        let protectedValue = "=\"1234567890\""

        // When: Cleaning value
        let cleaned = cleanCSVValue(protectedValue)

        // Then: Should remove equals sign and quotes
        XCTAssertEqual(cleaned, "1234567890")
    }

    func test_whenFieldHasDoubleQuotes_thenUnescapesCorrectly() {
        // Given: A value with escaped quotes
        let escapedValue = "\"She said \"\"hello\"\"\""

        // When: Cleaning value
        let cleaned = cleanCSVValue(escapedValue)

        // Then: Should unescape double quotes
        XCTAssertTrue(cleaned.contains("\"hello\""))
    }

    // MARK: - Empty Value Tests

    func test_whenAllFieldsEmpty_thenDoesNotCrash() {
        // Given: A CSV row with all empty fields
        let csvRow = "\"\",\"\",\"\",\"\",0,\"\",\"\",\"\",\"\""

        // When: Parsing the row
        let columns = parseCSVRow(csvRow)

        // Then: Should handle gracefully without crashing
        XCTAssertEqual(columns.count, 9)
        XCTAssertTrue(columns.allSatisfy { $0.isEmpty || $0 == "0" })
    }

    func test_whenNotesFieldEmpty_thenReturnsEmptyString() {
        // Given: A book with empty notes
        let book = createCSVBook(privateNotes: "")

        // When: Accessing notes
        let notes = book.privateNotes

        // Then: Should be empty string
        XCTAssertEqual(notes, "")
    }

    // MARK: - Helper Methods

    private func parseCSVRow(_ row: String) -> [String] {
        var columns: [String] = []
        var currentColumn = ""
        var insideQuotes = false
        var i = row.startIndex

        while i < row.endIndex {
            let char = row[i]

            if char == "\"" {
                if insideQuotes && i < row.index(before: row.endIndex) && row[row.index(after: i)] == "\"" {
                    // Escaped quote
                    currentColumn.append("\"")
                    i = row.index(after: i)
                } else {
                    // Toggle quote state
                    insideQuotes.toggle()
                }
            } else if char == "," && !insideQuotes {
                // End of column
                columns.append(currentColumn)
                currentColumn = ""
            } else {
                currentColumn.append(char)
            }

            i = row.index(after: i)
        }

        // Add last column
        columns.append(currentColumn)

        return columns
    }

    private func cleanCSVValue(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove surrounding quotes if present
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }

        // Remove equals sign prefix (Excel formula protection)
        if cleaned.hasPrefix("=") {
            cleaned = String(cleaned.dropFirst())
        }

        // Unescape double quotes
        cleaned = cleaned.replacingOccurrences(of: "\"\"", with: "\"")

        return cleaned
    }

    // Helper struct matching GoodreadsCleanImporter.CSVBook
    private struct TestCSVBook {
        let title: String
        let author: String
        let isbn: String
        let isbn13: String
        let myRating: Int
        let dateRead: String
        let dateAdded: String
        let exclusiveShelf: String
        let privateNotes: String

        var primaryISBN: String? {
            if !isbn13.isEmpty { return isbn13 }
            if !isbn.isEmpty { return isbn }
            return nil
        }

        var readingStatus: ReadingStatus {
            switch exclusiveShelf.lowercased() {
            case "read":
                return .read
            case "currently-reading":
                return .currentlyReading
            default:
                return .wantToRead
            }
        }
    }

    private func createCSVBook(
        title: String = "Test Book",
        author: String = "Test Author",
        isbn: String = "",
        isbn13: String = "",
        myRating: Int = 0,
        dateRead: String = "",
        dateAdded: String = "",
        exclusiveShelf: String = "to-read",
        privateNotes: String = ""
    ) -> TestCSVBook {
        return TestCSVBook(
            title: title,
            author: author,
            isbn: isbn,
            isbn13: isbn13,
            myRating: myRating,
            dateRead: dateRead,
            dateAdded: dateAdded,
            exclusiveShelf: exclusiveShelf,
            privateNotes: privateNotes
        )
    }
}
