import Foundation
import SwiftData
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Knowledge Graph Query Tool
/// Foundation Models tool for querying the knowledge graph during conversations.
/// Enables the AI to find connections, themes, and relationships across the user's reading.

#if canImport(FoundationModels)

@available(iOS 26.0, *)
struct GraphQueryTool: Tool {
    let name = "queryKnowledgeGraph"
    let description = """
        Search the user's knowledge graph for connections between books, themes, characters, and concepts.
        Use this to find themes across books, character similarities, or patterns in reading interests.
        """

    @Generable
    struct Arguments {
        @Guide(description: "The search query - a theme, character, concept, or question")
        var query: String

        @Guide(description: "Filter by entity type: book, character, theme, concept, location, insight, or 'all'")
        var entityType: String?

        @Guide(description: "Maximum number of results to return", .range(1...10))
        var limit: Int?
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let graphService = KnowledgeGraphService.shared
        let limit = arguments.limit ?? 5
        let entityType = arguments.entityType ?? "all"

        // Determine node type filter
        let nodeType: KnowledgeNode.NodeType? = {
            switch entityType.lowercased() {
            case "book": return .book
            case "character": return .character
            case "theme": return .theme
            case "concept": return .concept
            case "location": return .location
            case "insight": return .insight
            default: return nil
            }
        }()

        // Try semantic search first
        do {
            let results = try graphService.findSimilarNodes(
                to: arguments.query,
                type: nodeType,
                threshold: 0.4,
                limit: limit
            )

            if !results.isEmpty {
                return formatResults(results.map { $0.node }, query: arguments.query)
            }
        } catch {
            // Fall through to text search
        }

        // Fall back to text search
        do {
            let results = try graphService.findNodes(
                matching: arguments.query,
                type: nodeType,
                limit: limit
            )

            if results.isEmpty {
                return "No entities found matching '\(arguments.query)'"
            }

            return formatResults(results, query: arguments.query)
        } catch {
            return "Error searching knowledge graph: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func formatResults(_ nodes: [KnowledgeNode], query: String) -> String {
        var result = "Found \(nodes.count) entities related to '\(query)':\n\n"

        for node in nodes {
            let bookTitles = node.sourceBooks.map { $0.title }
            result += "• \(node.type.displayName): \(node.label)"
            if !bookTitles.isEmpty {
                result += " (in: \(bookTitles.prefix(2).joined(separator: ", ")))"
            }
            result += "\n"
        }

        return result
    }
}

// MARK: - Find Connections Tool

@available(iOS 26.0, *)
struct FindConnectionsTool: Tool {
    let name = "findConnections"
    let description = """
        Find what connects two books, authors, or themes in the user's reading history.
        Use when asked "What do these books have in common?" or similar questions.
        """

    @Generable
    struct Arguments {
        @Guide(description: "First entity to compare (book title, theme, or character)")
        var entity1: String

        @Guide(description: "Second entity to compare")
        var entity2: String
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let graphService = KnowledgeGraphService.shared

        // Find both entities
        guard let node1 = try graphService.findNodes(matching: arguments.entity1, limit: 1).first,
              let node2 = try graphService.findNodes(matching: arguments.entity2, limit: 1).first else {
            return "Could not find one or both entities in the knowledge graph"
        }

        // Find paths between them
        var pathDescriptions: [String] = []
        if let paths = try? graphService.findPaths(from: node1, to: node2, maxDepth: 3) {
            for path in paths.prefix(3) {
                let description = path.map { $0.displayDescription }.joined(separator: " → ")
                pathDescriptions.append(description)
            }
        }

        // Find shared themes (if both are books)
        var sharedThemes: [String] = []
        if node1.type == .book && node2.type == .book {
            if let shared = try? graphService.findSharedThemes(bookIds: [
                node1.originBookId ?? node1.id.uuidString,
                node2.originBookId ?? node2.id.uuidString
            ]) {
                sharedThemes = shared.map { $0.label }
            }
        }

        var result = "Connections between '\(arguments.entity1)' and '\(arguments.entity2)':\n\n"

        if !sharedThemes.isEmpty {
            result += "Shared themes: \(sharedThemes.joined(separator: ", "))\n"
        }

        if !pathDescriptions.isEmpty {
            result += "Connected via: \(pathDescriptions.first ?? "")\n"
        }

        if sharedThemes.isEmpty && pathDescriptions.isEmpty {
            result = "No direct connections found between '\(arguments.entity1)' and '\(arguments.entity2)'"
        }

        return result
    }
}

// MARK: - Get Reading Patterns Tool

@available(iOS 26.0, *)
struct GetReadingPatternsTool: Tool {
    let name = "getReadingPatterns"
    let description = """
        Analyze the user's reading patterns to find favorite themes, recurring interests,
        and areas of focus. Use to personalize recommendations or surface insights.
        """

    @Generable
    struct Arguments {
        @Guide(description: "How many top items to return", .range(1...10))
        var limit: Int?
    }

    @MainActor
    func call(arguments: Arguments) async throws -> String {
        let graphService = KnowledgeGraphService.shared
        let limit = arguments.limit ?? 5

        // Get top themes
        let topThemes = (try? graphService.getTopThemes(limit: limit)) ?? []

        // Get graph statistics
        let stats = try? graphService.getStatistics()

        if topThemes.isEmpty {
            return "Not enough reading data yet to identify patterns"
        }

        var result = "Reading Pattern Analysis:\n\n"

        result += "Top Themes:\n"
        for theme in topThemes {
            result += "• \(theme.label) - \(theme.mentionCount) mentions across \(theme.sourceBooks.count) books\n"
        }

        if let stats = stats {
            result += "\nGraph Statistics:\n"
            result += "• Total entities tracked: \(stats.totalNodes)\n"
            result += "• Connections discovered: \(stats.totalEdges)\n"
            result += "• Books indexed: \(stats.nodesByType[.book] ?? 0)\n"
        }

        return result
    }
}

#endif

// MARK: - Tool Registration

/// Register knowledge graph tools with a Foundation Models session
@MainActor
func registerKnowledgeGraphTools() -> [Any] {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
        return [
            GraphQueryTool(),
            FindConnectionsTool(),
            GetReadingPatternsTool()
        ]
    }
    #endif
    return []
}
