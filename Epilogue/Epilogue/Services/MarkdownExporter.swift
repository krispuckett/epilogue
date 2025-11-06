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
