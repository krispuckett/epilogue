import Foundation
import SwiftData

// MARK: - Knowledge Edge
/// A directed edge in the knowledge graph connecting two nodes.
///
/// Edges represent relationships like:
/// - Book → Character (mentions)
/// - Book → Theme (explores)
/// - Character → Theme (embodies)
/// - User → Quote (resonates)
///
/// Each edge has:
/// - A relationship type
/// - A weight (0-1) indicating strength
/// - Evidence (quotes/notes supporting the connection)

@Model
final class KnowledgeEdge {
    // MARK: - Identity

    var id: UUID = UUID()

    /// The type of relationship
    var relationshipType: String = ""  // Stored as string for SwiftData

    // MARK: - Nodes

    /// The source node of this edge
    var sourceNode: KnowledgeNode?

    /// The target node of this edge
    var targetNode: KnowledgeNode?

    // MARK: - Weight & Confidence

    /// Strength of the connection (0.0 - 1.0)
    /// Higher = stronger relationship
    var weight: Double = 0.5

    /// Confidence score from extraction (0.0 - 1.0)
    /// Higher = more certain about this connection
    var confidence: Double = 0.8

    /// Number of times this relationship has been observed
    var occurrenceCount: Int = 1

    // MARK: - Evidence

    /// Text excerpts that support this edge
    /// Stored as JSON array of strings
    var evidenceJSON: Data?

    /// IDs of notes that support this edge - stored as JSON Data
    var supportingNoteIdsData: Data?

    /// IDs of quotes that support this edge - stored as JSON Data
    var supportingQuoteIdsData: Data?

    // MARK: - Metadata

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// Whether this edge was created by user action (vs automatic extraction)
    var isUserCreated: Bool = false

    /// Optional context about when/how this was discovered
    var discoveryContext: String?

    // MARK: - Initialization

    init(
        source: KnowledgeNode,
        target: KnowledgeNode,
        relationship: EdgeType,
        weight: Double = 0.5,
        confidence: Double = 0.8,
        isUserCreated: Bool = false
    ) {
        self.id = UUID()
        self.sourceNode = source
        self.targetNode = target
        self.relationshipType = relationship.rawValue
        self.weight = min(1.0, max(0.0, weight))
        self.confidence = min(1.0, max(0.0, confidence))
        self.occurrenceCount = 1
        self.evidenceJSON = nil
        self.supportingNoteIdsData = nil
        self.supportingQuoteIdsData = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isUserCreated = isUserCreated
        self.discoveryContext = nil
    }

    // MARK: - Computed Properties

    var relationship: EdgeType {
        get { EdgeType(rawValue: relationshipType) ?? .relatedTo }
        set { relationshipType = newValue.rawValue }
    }

    /// Get evidence as string array
    var evidence: [String] {
        get {
            guard let data = evidenceJSON else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            evidenceJSON = try? JSONEncoder().encode(newValue)
        }
    }

    /// Get supporting note IDs
    var supportingNoteIds: [UUID] {
        get {
            guard let data = supportingNoteIdsData else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            supportingNoteIdsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Get supporting quote IDs
    var supportingQuoteIds: [UUID] {
        get {
            guard let data = supportingQuoteIdsData else { return [] }
            return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
        }
        set {
            supportingQuoteIdsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Combined strength score for ranking
    var strength: Double {
        // Weight the raw weight by confidence and occurrence
        let occurrenceBonus = min(1.0, Double(occurrenceCount) / 10.0)
        let userBonus = isUserCreated ? 0.2 : 0.0
        return (weight * confidence) + (occurrenceBonus * 0.3) + userBonus
    }

    /// Human-readable description of this edge
    var displayDescription: String {
        guard let source = sourceNode, let target = targetNode else {
            return "Unknown connection"
        }
        return "\(source.label) \(relationship.verbPhrase) \(target.label)"
    }

    // MARK: - Methods

    /// Add evidence supporting this edge
    func addEvidence(_ text: String, noteId: UUID? = nil, quoteId: UUID? = nil) {
        var currentEvidence = evidence
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Avoid duplicates
        guard !trimmed.isEmpty, !currentEvidence.contains(trimmed) else { return }

        // Keep only the 5 most recent pieces of evidence
        if currentEvidence.count >= 5 {
            currentEvidence.removeFirst()
        }
        currentEvidence.append(trimmed)
        evidence = currentEvidence

        if let noteId = noteId, !supportingNoteIds.contains(noteId) {
            supportingNoteIds.append(noteId)
        }
        if let quoteId = quoteId, !supportingQuoteIds.contains(quoteId) {
            supportingQuoteIds.append(quoteId)
        }

        occurrenceCount += 1
        updatedAt = Date()

        // Strengthen the weight based on evidence
        weight = min(1.0, weight + 0.05)
    }

    /// Check if this edge connects two specific node types
    func connects(_ type1: KnowledgeNode.NodeType, to type2: KnowledgeNode.NodeType) -> Bool {
        guard let source = sourceNode, let target = targetNode else { return false }
        return source.type == type1 && target.type == type2
    }
}

// MARK: - Edge Type

extension KnowledgeEdge {
    enum EdgeType: String, Codable, CaseIterable {
        // Book relationships
        case mentions = "mentions"           // Book → Character/Location
        case explores = "explores"           // Book → Theme
        case writtenBy = "written_by"        // Book → Author
        case partOfSeries = "part_of_series" // Book → Book (series connection)
        case inspiredBy = "inspired_by"      // Book → Book (user noted connection)

        // Character relationships
        case embodies = "embodies"           // Character → Theme
        case appearsIn = "appears_in"        // Character → Book
        case resembles = "resembles"         // Character → Character (cross-book)
        case relatedTo = "related_to"        // Character → Character (same book)

        // Theme relationships
        case themeOf = "theme_of"            // Theme → Book
        case connectedTheme = "connected"    // Theme → Theme

        // User relationships
        case resonates = "resonates"         // User → Quote/Theme
        case confusedBy = "confused_by"      // User → Concept
        case interestedIn = "interested_in"  // User → Theme
        case noted = "noted"                 // User → Insight

        // General
        case associatedWith = "associated"   // Generic association

        var verbPhrase: String {
            switch self {
            case .mentions: return "mentions"
            case .explores: return "explores"
            case .writtenBy: return "was written by"
            case .partOfSeries: return "is part of the same series as"
            case .inspiredBy: return "was inspired by"
            case .embodies: return "embodies"
            case .appearsIn: return "appears in"
            case .resembles: return "resembles"
            case .relatedTo: return "is related to"
            case .themeOf: return "is a theme of"
            case .connectedTheme: return "connects to"
            case .resonates: return "resonates with"
            case .confusedBy: return "was confused by"
            case .interestedIn: return "is interested in"
            case .noted: return "noted"
            case .associatedWith: return "is associated with"
            }
        }

        var displayName: String {
            switch self {
            case .mentions: return "Mentions"
            case .explores: return "Explores"
            case .writtenBy: return "Written By"
            case .partOfSeries: return "Series"
            case .inspiredBy: return "Inspired By"
            case .embodies: return "Embodies"
            case .appearsIn: return "Appears In"
            case .resembles: return "Resembles"
            case .relatedTo: return "Related To"
            case .themeOf: return "Theme Of"
            case .connectedTheme: return "Connected"
            case .resonates: return "Resonates"
            case .confusedBy: return "Confused By"
            case .interestedIn: return "Interested In"
            case .noted: return "Noted"
            case .associatedWith: return "Associated"
            }
        }

        /// Whether this edge type is bidirectional
        var isBidirectional: Bool {
            switch self {
            case .resembles, .relatedTo, .connectedTheme, .associatedWith:
                return true
            default:
                return false
            }
        }
    }
}

