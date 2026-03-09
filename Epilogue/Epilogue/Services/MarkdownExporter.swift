import Foundation

// MARK: - Markdown Export Service
class MarkdownExporter {

    enum ExportFormat {
        case standard
        case obsidian
        case notion
    }

    struct ExportOptions: Equatable {
        var includeBook: Bool = true
        var includePageNumber: Bool = true
        var includeDateTime: Bool = true
        var includeCaptureSource: Bool = true
        var format: ExportFormat = .standard
    }

    // MARK: - Quote Export

    static func exportQuote(
        _ quote: CapturedQuote,
        options: ExportOptions
    ) -> String {
        switch options.format {
        case .standard:
            return exportQuoteStandard(quote, options: options)
        case .obsidian:
            return exportQuoteObsidian(quote, options: options)
        case .notion:
            return exportQuoteNotion(quote, options: options)
        }
    }

    private static func exportQuoteStandard(_ quote: CapturedQuote, options: ExportOptions) -> String {
        var markdown = ""

        // Quote text
        let quoteText = quote.text ?? ""
        markdown += "> \"\(quoteText)\"\n\n"

        // Attribution
        if options.includeBook {
            if let author = quote.author, let bookTitle = quote.book?.title {
                markdown += "— \(author), *\(bookTitle)*"
            } else if let author = quote.author {
                markdown += "— \(author)"
            } else if let bookTitle = quote.book?.title {
                markdown += "— *\(bookTitle)*"
            }

            // Page number on same line
            if options.includePageNumber, let page = quote.pageNumber {
                markdown += "  \nPage \(page)"
            }
            markdown += "\n\n"
        }

        // Metadata
        if options.includeDateTime {
            if let timestamp = quote.timestamp {
                markdown += "*\(formatDate(timestamp))*\n"
            }
        }

        return markdown
    }

    private static func exportQuoteObsidian(_ quote: CapturedQuote, options: ExportOptions) -> String {
        var markdown = ""

        // YAML frontmatter
        markdown += "---\n"

        if let bookTitle = quote.book?.title {
            markdown += "title: Quote from \(bookTitle)\n"
        } else {
            markdown += "title: Quote\n"
        }

        if options.includeBook {
            if let author = quote.author {
                markdown += "author: \(author)\n"
            }
            if let bookTitle = quote.book?.title {
                markdown += "book: \(bookTitle)\n"
            }
        }

        if options.includePageNumber, let page = quote.pageNumber {
            markdown += "page: \(page)\n"
        }


        if options.includeDateTime, let timestamp = quote.timestamp {
            markdown += "date: \(formatDateISO(timestamp))\n"
        }

        // Tags
        var tags: [String] = ["quote"]
        if let bookTitle = quote.book?.title {
            tags.append(bookTitle.lowercased().replacingOccurrences(of: " ", with: "-"))
        }
        if let author = quote.author {
            tags.append(author.lowercased().replacingOccurrences(of: " ", with: "-"))
        }
        markdown += "tags: [\(tags.joined(separator: ", "))]\n"

        markdown += "---\n\n"

        // Quote text
        let quoteText = quote.text ?? ""
        markdown += "> \"\(quoteText)\"\n\n"

        // Attribution line
        if options.includeBook {
            var attribution = "— "
            if let author = quote.author {
                attribution += "\(author), "
            }
            if let bookTitle = quote.book?.title {
                attribution += "*\(bookTitle)*"
            }
            if options.includePageNumber, let page = quote.pageNumber {
                attribution += " (p. \(page))"
            }
            markdown += "\(attribution)\n"
        }

        return markdown
    }

    private static func exportQuoteNotion(_ quote: CapturedQuote, options: ExportOptions) -> String {
        var markdown = ""

        // Title
        if let bookTitle = quote.book?.title {
            markdown += "# Quote from \(bookTitle)\n\n"
        } else {
            markdown += "# Quote\n\n"
        }

        // Quote text
        let quoteText = quote.text ?? ""
        markdown += "> \"\(quoteText)\"\n\n"

        // Metadata block
        if options.includeBook || options.includePageNumber || options.includeDateTime {
            if let author = quote.author {
                markdown += "**Author:** \(author)  \n"
            }
            if let bookTitle = quote.book?.title {
                markdown += "**Book:** \(bookTitle)  \n"
            }
            if options.includePageNumber, let page = quote.pageNumber {
                markdown += "**Page:** \(page)  \n"
            }
            if options.includeDateTime, let timestamp = quote.timestamp {
                markdown += "**Captured:** \(formatDate(timestamp))\n"
            }
        }

        return markdown
    }

    // MARK: - Note Export

    static func exportNote(
        _ note: CapturedNote,
        options: ExportOptions
    ) -> String {
        switch options.format {
        case .standard:
            return exportNoteStandard(note, options: options)
        case .obsidian:
            return exportNoteObsidian(note, options: options)
        case .notion:
            return exportNoteNotion(note, options: options)
        }
    }

    private static func exportNoteStandard(_ note: CapturedNote, options: ExportOptions) -> String {
        var markdown = ""

        // Generate intelligent title using NaturalLanguage
        let content = note.content ?? ""
        let intelligentTitle = IntelligentTitleGenerator.generateTitle(from: content, maxLength: 60)

        if options.includeBook, let bookTitle = note.book?.title {
            markdown += "# Note from \(bookTitle): \(intelligentTitle)\n\n"
        } else {
            markdown += "# \(intelligentTitle)\n\n"
        }

        // Content
        markdown += "\(content)\n\n"

        // Metadata separator
        markdown += "---\n\n"

        // Book metadata
        if options.includeBook {
            if let bookTitle = note.book?.title {
                var bookLine = "**From:** *\(bookTitle)*"
                if let author = note.book?.author {
                    bookLine += " by \(author)"
                }
                markdown += "\(bookLine)  \n"
            }
        }

        if options.includePageNumber, let page = note.pageNumber {
            markdown += "**Page:** \(page)  \n"
        }

        if options.includeDateTime, let timestamp = note.timestamp {
            markdown += "**Created:** \(formatDateWithTime(timestamp))  \n"
        }


        return markdown
    }

    private static func exportNoteObsidian(_ note: CapturedNote, options: ExportOptions) -> String {
        var markdown = ""

        let content = note.content ?? ""
        let intelligentTitle = IntelligentTitleGenerator.generateTitle(from: content, maxLength: 60)

        // YAML frontmatter
        markdown += "---\n"

        if let bookTitle = note.book?.title {
            markdown += "title: Note from \(bookTitle): \(intelligentTitle)\n"
        } else {
            markdown += "title: \(intelligentTitle)\n"
        }

        if options.includeBook {
            if let bookTitle = note.book?.title {
                markdown += "book: \(bookTitle)\n"
            }
            if let author = note.book?.author {
                markdown += "author: \(author)\n"
            }
        }

        if options.includePageNumber, let page = note.pageNumber {
            markdown += "page: \(page)\n"
        }


        if options.includeDateTime, let timestamp = note.timestamp {
            markdown += "date: \(formatDateISO(timestamp))\n"
        }

        // Tags
        var tags: [String] = ["note"]
        if let bookTitle = note.book?.title {
            tags.append(bookTitle.lowercased().replacingOccurrences(of: " ", with: "-"))
        }
        markdown += "tags: [\(tags.joined(separator: ", "))]\n"

        markdown += "---\n\n"

        // Content
        markdown += "\(content)\n"

        return markdown
    }

    private static func exportNoteNotion(_ note: CapturedNote, options: ExportOptions) -> String {
        var markdown = ""

        let content = note.content ?? ""
        let intelligentTitle = IntelligentTitleGenerator.generateTitle(from: content, maxLength: 60)

        // Title
        if let bookTitle = note.book?.title {
            markdown += "# Note from \(bookTitle): \(intelligentTitle)\n\n"
        } else {
            markdown += "# \(intelligentTitle)\n\n"
        }

        // Content
        markdown += "\(content)\n\n"

        // Metadata block
        if options.includeBook || options.includePageNumber || options.includeDateTime {
            if let bookTitle = note.book?.title {
                markdown += "**Book:** \(bookTitle)  \n"
            }
            if let author = note.book?.author {
                markdown += "**Author:** \(author)  \n"
            }
            if options.includePageNumber, let page = note.pageNumber {
                markdown += "**Page:** \(page)  \n"
            }
            if options.includeDateTime, let timestamp = note.timestamp {
                markdown += "**Captured:** \(formatDate(timestamp))\n"
            }
        }

        return markdown
    }

    // MARK: - Batch Export

    static func exportMultiple(
        notes: [CapturedNote],
        quotes: [CapturedQuote],
        options: ExportOptions
    ) -> String {
        var markdown = ""
        let totalCount = notes.count + quotes.count

        // Header
        markdown += "# Epilogue Notes Export\n\n"
        markdown += "*Exported on \(formatDate(Date()))*  \n"
        markdown += "*\(totalCount) item\(totalCount == 1 ? "" : "s")*\n\n"
        markdown += "---\n\n"

        // Combine and sort by date
        var items: [(date: Date, isNote: Bool, note: CapturedNote?, quote: CapturedQuote?)] = []

        for note in notes {
            items.append((date: note.timestamp ?? Date(), isNote: true, note: note, quote: nil))
        }

        for quote in quotes {
            items.append((date: quote.timestamp ?? Date(), isNote: false, note: nil, quote: quote))
        }

        items.sort { $0.date > $1.date }

        // Export each item
        for (index, item) in items.enumerated() {
            if let note = item.note {
                markdown += exportNote(note, options: options)
            } else if let quote = item.quote {
                markdown += exportQuote(quote, options: options)
            }

            // Add separator between items (except last one)
            if index < items.count - 1 {
                markdown += "\n---\n\n"
            }
        }

        return markdown
    }

    // MARK: - Book Export

    /// Export a complete BookModel with all notes, quotes, questions, and session summary
    static func exportBook(
        _ book: BookModel,
        options: ExportOptions
    ) -> String {
        switch options.format {
        case .standard:
            return exportBookStandard(book, options: options)
        case .obsidian:
            return exportBookObsidian(book, options: options)
        case .notion:
            return exportBookNotion(book, options: options)
        }
    }

    private static func exportBookStandard(_ book: BookModel, options: ExportOptions) -> String {
        var md = ""

        md += "# \(book.title)\n\n"
        md += "**Author:** \(book.author)\n"
        if let isbn = book.isbn { md += "**ISBN:** \(isbn)\n" }
        if let year = book.publishedYear { md += "**Published:** \(year)\n" }
        if let pages = book.pageCount { md += "**Pages:** \(pages)\n" }
        md += "**Status:** \(book.readingStatus)\n"
        if let rating = book.userRating {
            md += "**Rating:** \(String(format: "%.1f", rating))/5\n"
        }
        if book.currentPage > 0 {
            md += "**Progress:** Page \(book.currentPage)"
            if let total = book.pageCount, total > 0 {
                md += " of \(total) (\(Int(Double(book.currentPage) / Double(total) * 100))%)"
            }
            md += "\n"
        }
        md += "**Added:** \(formatDate(book.dateAdded))\n"
        md += "\n"

        // Description
        if let desc = book.userDescription ?? book.desc, !desc.isEmpty {
            md += "## Description\n\n\(desc)\n\n"
        }

        // Quotes
        let quotes = (book.quotes ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !quotes.isEmpty {
            md += "## Quotes (\(quotes.count))\n\n"
            for quote in quotes {
                md += exportQuoteInline(quote, options: options)
                md += "\n"
            }
        }

        // Notes
        let notes = (book.notes ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !notes.isEmpty {
            md += "## Notes (\(notes.count))\n\n"
            for note in notes {
                md += exportNoteInline(note, options: options)
                md += "\n"
            }
        }

        // Questions
        let questions = (book.questions ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !questions.isEmpty {
            md += "## Questions (\(questions.count))\n\n"
            for question in questions {
                if let content = question.content {
                    md += "**Q:** \(content)\n"
                    if let answer = question.answer {
                        md += "**A:** \(answer)\n"
                    }
                    if options.includePageNumber, let page = question.pageNumber {
                        md += "*Page \(page)*\n"
                    }
                    md += "\n"
                }
            }
        }

        // Reading Sessions
        let sessions = (book.readingSessions ?? []).sorted { $0.startDate > $1.startDate }
        if !sessions.isEmpty {
            md += "## Reading Sessions (\(sessions.count))\n\n"
            let totalMinutes = sessions.reduce(0.0) { $0 + $1.duration } / 60.0
            let totalPages = sessions.reduce(0) { $0 + $1.pagesRead }
            md += "**Total time:** \(Int(totalMinutes)) minutes\n"
            md += "**Total pages:** \(totalPages)\n\n"
            for session in sessions {
                let mins = Int(session.duration / 60)
                md += "- \(formatDate(session.startDate)): \(mins) min, \(session.pagesRead) pages"
                md += " (p. \(session.startPage)–\(session.endPage))\n"
            }
            md += "\n"
        }

        md += "---\n*Exported from Epilogue on \(formatDate(Date()))*\n"
        return md
    }

    private static func exportBookObsidian(_ book: BookModel, options: ExportOptions) -> String {
        var md = ""

        // YAML frontmatter
        md += "---\n"
        md += "title: \"\(book.title)\"\n"
        md += "author: \"\(book.author)\"\n"
        if let isbn = book.isbn { md += "isbn: \"\(isbn)\"\n" }
        if let year = book.publishedYear { md += "published: \(year)\n" }
        if let pages = book.pageCount { md += "pages: \(pages)\n" }
        md += "status: \"\(book.readingStatus)\"\n"
        if let rating = book.userRating {
            md += "rating: \(String(format: "%.1f", rating))\n"
        }
        md += "date_added: \(formatDateISO(book.dateAdded))\n"

        var tags: [String] = ["book"]
        tags.append(book.author.lowercased().replacingOccurrences(of: " ", with: "-"))
        if let themes = book.keyThemes {
            tags.append(contentsOf: themes.map { $0.lowercased().replacingOccurrences(of: " ", with: "-") })
        }
        md += "tags: [\(tags.joined(separator: ", "))]\n"
        md += "---\n\n"

        // Body
        md += "# \(book.title)\n\n"

        if let desc = book.userDescription ?? book.desc, !desc.isEmpty {
            md += "> \(desc)\n\n"
        }

        // Quotes
        let quotes = (book.quotes ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !quotes.isEmpty {
            md += "## Quotes\n\n"
            for quote in quotes {
                md += exportQuoteInline(quote, options: options)
                md += "\n"
            }
        }

        // Notes
        let notes = (book.notes ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !notes.isEmpty {
            md += "## Notes\n\n"
            for note in notes {
                md += exportNoteInline(note, options: options)
                md += "\n"
            }
        }

        // Questions
        let questions = (book.questions ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !questions.isEmpty {
            md += "## Questions\n\n"
            for question in questions {
                if let content = question.content {
                    md += "- **Q:** \(content)\n"
                    if let answer = question.answer {
                        md += "  **A:** \(answer)\n"
                    }
                }
            }
            md += "\n"
        }

        return md
    }

    private static func exportBookNotion(_ book: BookModel, options: ExportOptions) -> String {
        var md = ""

        md += "# \(book.title)\n\n"

        // Metadata table
        md += "| Property | Value |\n"
        md += "|----------|-------|\n"
        md += "| Author | \(book.author) |\n"
        if let isbn = book.isbn { md += "| ISBN | \(isbn) |\n" }
        if let year = book.publishedYear { md += "| Published | \(year) |\n" }
        if let pages = book.pageCount { md += "| Pages | \(pages) |\n" }
        md += "| Status | \(book.readingStatus) |\n"
        if let rating = book.userRating {
            md += "| Rating | \(String(format: "%.1f", rating))/5 |\n"
        }
        md += "| Added | \(formatDate(book.dateAdded)) |\n"
        md += "\n"

        if let desc = book.userDescription ?? book.desc, !desc.isEmpty {
            md += "## Description\n\n\(desc)\n\n"
        }

        let quotes = (book.quotes ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !quotes.isEmpty {
            md += "## Quotes\n\n"
            for quote in quotes {
                md += exportQuoteInline(quote, options: options)
                md += "\n"
            }
        }

        let notes = (book.notes ?? []).sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        if !notes.isEmpty {
            md += "## Notes\n\n"
            for note in notes {
                md += exportNoteInline(note, options: options)
                md += "\n"
            }
        }

        return md
    }

    // MARK: - Inline Helpers (for book-level export)

    private static func exportQuoteInline(_ quote: CapturedQuote, options: ExportOptions) -> String {
        var md = ""
        let text = quote.text ?? ""
        md += "> \"\(text)\"\n"
        if options.includePageNumber, let page = quote.pageNumber {
            md += "> — Page \(page)\n"
        }
        if let notes = quote.notes, !notes.isEmpty {
            md += "\n**Note:** \(notes)\n"
        }
        if options.includeDateTime, let ts = quote.timestamp {
            md += "*\(formatDate(ts))*\n"
        }
        return md
    }

    private static func exportNoteInline(_ note: CapturedNote, options: ExportOptions) -> String {
        var md = ""
        let content = note.content ?? ""
        let title = IntelligentTitleGenerator.generateTitle(from: content, maxLength: 50)
        md += "### \(title)\n\n"
        md += "\(content)\n"
        if options.includePageNumber, let page = note.pageNumber {
            md += "\n*Page \(page)*"
        }
        if options.includeDateTime, let ts = note.timestamp {
            md += "  *\(formatDate(ts))*"
        }
        md += "\n"
        return md
    }

    static func generateFilename(for book: BookModel) -> String {
        let sanitized = book.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: " -")
        return "\(sanitized) - \(book.author).md"
    }

    // MARK: - Filename Generation

    static func generateFilename(for note: CapturedNote) -> String {
        let content = note.content ?? ""
        return IntelligentTitleGenerator.generateFilename(
            from: content,
            bookTitle: note.book?.title,
            author: note.book?.author,
            isQuote: false
        )
    }

    static func generateFilename(for quote: CapturedQuote) -> String {
        if let bookTitle = quote.book?.title, let author = quote.author {
            return "Quote - \(bookTitle) - \(author).md"
        } else if let bookTitle = quote.book?.title {
            return "Quote - \(bookTitle).md"
        } else {
            let timestamp = quote.timestamp ?? Date()
            return "Quote - \(formatDate(timestamp)).md"
        }
    }

    static func generateBatchFilename(count: Int) -> String {
        return "Epilogue Export - \(count) items - \(formatDate(Date())).md"
    }

    // MARK: - Date Formatters

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private static func formatDateWithTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }

    private static func formatDateISO(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
