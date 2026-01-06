import Foundation
import SwiftData

// MARK: - Knowledge Node
/// A node in the Epilogue knowledge graph representing an entity:
/// books, characters, themes, concepts, authors, locations, or user insights.
///
/// Each node has:
/// - A semantic embedding for similarity search
/// - Source tracking back to original content
/// - Importance weighting based on user engagement

@Model
final class KnowledgeNode {
    // MARK: - Identity

    var id: UUID = UUID()

    /// The type of entity this node represents
    var nodeType: String = ""  // Stored as string for SwiftData compatibility

    /// The canonical label (e.g., "Frodo Baggins", "redemption", "Project Hail Mary")
    var label: String = ""

    /// Normalized label for matching (lowercase, trimmed)
    var normalizedLabel: String = ""

    /// Optional description or context
    var nodeDescription: String?

    // MARK: - Semantic Embedding

    /// 300-dimensional semantic embedding from NLEmbedding
    /// Stored as Data for efficient SwiftData storage
    var embeddingData: Data?

    /// Whether the embedding has been computed
    var hasEmbedding: Bool = false

    // MARK: - Importance & Engagement

    /// Importance score (1-5) based on frequency and user engagement
    var importance: Int = 1

    /// Number of times this entity appears across all content
    var mentionCount: Int = 1

    /// Whether the user has explicitly marked this as important
    var isUserHighlighted: Bool = false

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// The book context where this was first discovered (for characters/themes)
    var originBookId: String?

    // MARK: - Relationships

    /// Books where this entity appears
    @Relationship(deleteRule: .nullify, inverse: \BookModel.knowledgeNodes)
    var sourceBooks: [BookModel]

    /// Notes that mention this entity
    @Relationship(deleteRule: .nullify)
    var sourceNotes: [CapturedNote]

    /// Quotes that mention this entity
    @Relationship(deleteRule: .nullify)
    var sourceQuotes: [CapturedQuote]

    /// Outgoing edges from this node
    @Relationship(deleteRule: .cascade, inverse: \KnowledgeEdge.sourceNode)
    var outgoingEdges: [KnowledgeEdge]

    /// Incoming edges to this node
    @Relationship(deleteRule: .cascade, inverse: \KnowledgeEdge.targetNode)
    var incomingEdges: [KnowledgeEdge]

    // MARK: - Initialization

    init(
        type: NodeType,
        label: String,
        description: String? = nil,
        originBookId: String? = nil
    ) {
        self.id = UUID()
        self.nodeType = type.rawValue
        self.label = label
        self.normalizedLabel = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.nodeDescription = description
        self.embeddingData = nil
        self.hasEmbedding = false
        self.importance = 1
        self.mentionCount = 1
        self.isUserHighlighted = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.originBookId = originBookId
        self.sourceBooks = []
        self.sourceNotes = []
        self.sourceQuotes = []
        self.outgoingEdges = []
        self.incomingEdges = []
    }

    // MARK: - Computed Properties

    var type: NodeType {
        get { NodeType(rawValue: nodeType) ?? .concept }
        set { nodeType = newValue.rawValue }
    }

    /// Get the embedding as a Float array
    var embedding: [Float]? {
        get {
            guard let data = embeddingData else { return nil }
            return data.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
        }
        set {
            guard let values = newValue else {
                embeddingData = nil
                hasEmbedding = false
                return
            }
            embeddingData = values.withUnsafeBytes { Data($0) }
            hasEmbedding = true
        }
    }

    /// All connected nodes (both directions)
    var connectedNodes: [KnowledgeNode] {
        let outgoing = outgoingEdges.compactMap { $0.targetNode }
        let incoming = incomingEdges.compactMap { $0.sourceNode }
        return Array(Set(outgoing + incoming))
    }

    /// Total engagement score for ranking
    var engagementScore: Double {
        let favoriteNotes = sourceNotes.filter { $0.isFavorite == true }.count
        let favoriteQuotes = sourceQuotes.filter { $0.isFavorite == true }.count
        let favoriteBonus = Double(favoriteNotes + favoriteQuotes) * 2.0
        let highlightBonus = isUserHighlighted ? 5.0 : 0.0

        return Double(mentionCount) + favoriteBonus + highlightBonus + Double(importance)
    }

    // MARK: - Methods

    /// Increment mention count and update importance
    func recordMention() {
        mentionCount += 1
        updatedAt = Date()

        // Auto-adjust importance based on mentions
        if mentionCount >= 20 && importance < 5 {
            importance = 5
        } else if mentionCount >= 10 && importance < 4 {
            importance = 4
        } else if mentionCount >= 5 && importance < 3 {
            importance = 3
        } else if mentionCount >= 2 && importance < 2 {
            importance = 2
        }
    }

    /// Check if this node matches a search term
    func matches(query: String) -> Bool {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedLabel.contains(normalizedQuery)
    }
}

// MARK: - Node Type

extension KnowledgeNode {
    enum NodeType: String, Codable, CaseIterable {
        case book = "book"
        case character = "character"
        case theme = "theme"
        case concept = "concept"
        case author = "author"
        case location = "location"
        case quote = "quote"
        case insight = "insight"  // User's own insight/realization

        var displayName: String {
            switch self {
            case .book: return "Book"
            case .character: return "Character"
            case .theme: return "Theme"
            case .concept: return "Concept"
            case .author: return "Author"
            case .location: return "Location"
            case .quote: return "Quote"
            case .insight: return "Insight"
            }
        }

        var iconName: String {
            switch self {
            case .book: return "book.closed.fill"
            case .character: return "person.fill"
            case .theme: return "sparkle"
            case .concept: return "lightbulb.fill"
            case .author: return "pencil"
            case .location: return "map.fill"
            case .quote: return "quote.opening"
            case .insight: return "brain.head.profile"
            }
        }
    }
}

