import Foundation

// MARK: - Literary Quotes for Loading States
struct LiteraryQuote {
    let text: String
    let author: String
    
    var formatted: String {
        return ""\(text)" — \(author)"
    }
}

struct LiteraryQuotes {
    static let loadingQuotes: [LiteraryQuote] = [
        LiteraryQuote(text: "A room without books is like a body without a soul", author: "Cicero"),
        LiteraryQuote(text: "So many books, so little time", author: "Frank Zappa"),
        LiteraryQuote(text: "A reader lives a thousand lives before he dies", author: "George R.R. Martin"),
        LiteraryQuote(text: "Books are a uniquely portable magic", author: "Stephen King"),
        LiteraryQuote(text: "The more that you read, the more things you will know", author: "Dr. Seuss"),
        LiteraryQuote(text: "Reading is to the mind what exercise is to the body", author: "Joseph Addison"),
        LiteraryQuote(text: "A book is a dream that you hold in your hand", author: "Neil Gaiman"),
        LiteraryQuote(text: "Words have no single fixed meaning", author: "Jorge Luis Borges"),
        LiteraryQuote(text: "Literature is the most agreeable way of ignoring life", author: "Fernando Pessoa"),
        LiteraryQuote(text: "Books fall open, you fall in", author: "David T.W. McCord"),
        LiteraryQuote(text: "There is no greater agony than bearing an untold story", author: "Maya Angelou"),
        LiteraryQuote(text: "Reading is escape, and the opposite of escape", author: "Nora Ephron")
    ]
    
    static func randomQuote() -> LiteraryQuote {
        return loadingQuotes.randomElement() ?? loadingQuotes[0]
    }
}