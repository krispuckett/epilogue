import Foundation
import SwiftData
import NaturalLanguage
import Accelerate

// MARK: - Knowledge Graph Service
/// Core service for managing the Epilogue knowledge graph.
///
/// Responsibilities:
/// - Node creation and lookup
/// - Edge creation and management
/// - Semantic similarity search via embeddings
/// - Graph traversal and querying
/// - Statistics and insights

@MainActor
final class KnowledgeGraphService {
    // MARK: - Singleton

    static let shared = KnowledgeGraphService()

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private let embeddingModel: NLEmbedding?

    // MARK: - Cache

    /// Node cache for fast lookup by normalized label
    private var nodeCache: [String: KnowledgeNode] = [:]
    private var lastCacheRefresh: Date = .distantPast
    private let cacheLifetime: TimeInterval = 300  // 5 minutes

    // MARK: - Initialization

    private init() {
        // Initialize embedding model for semantic similarity
        self.embeddingModel = NLEmbedding.wordEmbedding(for: .english)

        #if DEBUG
        if embeddingModel != nil {
            print("📊 KnowledgeGraphService: NLEmbedding loaded")
        } else {
            print("⚠️ KnowledgeGraphService: NLEmbedding not available")
        }
        #endif
    }

    /// Configure the service with a model context
    func configure(with context: ModelContext) {
        self.modelContext = context
        #if DEBUG
        print("📊 KnowledgeGraphService: Configured with ModelContext")
        #endif
    }

    // MARK: - Node Operations

    /// Find or create a node with the given label and type
    func findOrCreateNode(
        label: String,
        type: KnowledgeNode.NodeType,
        description: String? = nil,
        originBookId: String? = nil
    ) throws -> KnowledgeNode {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        let normalizedLabel = label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Check cache first
        let cacheKey = "\(type.rawValue):\(normalizedLabel)"
        if Date().timeIntervalSince(lastCacheRefresh) < cacheLifetime,
           let cached = nodeCache[cacheKey] {
            cached.recordMention()
            return cached
        }

        // Query for existing node
        let descriptor = FetchDescriptor<KnowledgeNode>(
            predicate: #Predicate<KnowledgeNode> { node in
                node.normalizedLabel == normalizedLabel && node.nodeType == type.rawValue
            }
        )

        if let existing = try context.fetch(descriptor).first {
            existing.recordMention()
            nodeCache[cacheKey] = existing
            return existing
        }

        // Create new node
        let node = KnowledgeNode(
            type: type,
            label: label,
            description: description,
            originBookId: originBookId
        )

        // Generate embedding asynchronously
        if let embedding = generateEmbedding(for: label) {
            node.embedding = embedding
        }

        context.insert(node)
        nodeCache[cacheKey] = node

        #if DEBUG
        print("📊 Created node: \(type.displayName) - \(label)")
        #endif

        return node
    }

    /// Find nodes matching a search query
    func findNodes(
        matching query: String,
        type: KnowledgeNode.NodeType? = nil,
        limit: Int = 10
    ) throws -> [KnowledgeNode] {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var descriptor = FetchDescriptor<KnowledgeNode>(
            predicate: #Predicate<KnowledgeNode> { node in
                node.normalizedLabel.contains(normalizedQuery)
            },
            sortBy: [SortDescriptor(\.importance, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        var results = try context.fetch(descriptor)

        // Filter by type if specified
        if let type = type {
            results = results.filter { $0.type == type }
        }

        return results
    }

    /// Find semantically similar nodes using embeddings
    func findSimilarNodes(
        to query: String,
        type: KnowledgeNode.NodeType? = nil,
        threshold: Float = 0.5,
        limit: Int = 10
    ) throws -> [(node: KnowledgeNode, similarity: Float)] {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        guard let queryEmbedding = generateEmbedding(for: query) else {
            // Fall back to text matching
            return try findNodes(matching: query, type: type, limit: limit)
                .map { ($0, 1.0) }
        }

        // Fetch all nodes with embeddings
        let descriptor = FetchDescriptor<KnowledgeNode>(
            predicate: #Predicate<KnowledgeNode> { $0.hasEmbedding }
        )

        var allNodes = try context.fetch(descriptor)

        // Filter by type if specified
        if let type = type {
            allNodes = allNodes.filter { $0.type == type }
        }

        // Calculate similarities
        var similarities: [(node: KnowledgeNode, similarity: Float)] = []

        for node in allNodes {
            guard let nodeEmbedding = node.embedding else { continue }

            let similarity = cosineSimilarity(queryEmbedding, nodeEmbedding)
            if similarity >= threshold {
                similarities.append((node, similarity))
            }
        }

        // Sort by similarity and limit
        return similarities
            .sorted { $0.similarity > $1.similarity }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Edge Operations

    /// Create or strengthen an edge between two nodes
    func createEdge(
        from source: KnowledgeNode,
        to target: KnowledgeNode,
        relationship: KnowledgeEdge.EdgeType,
        weight: Double = 0.5,
        confidence: Double = 0.8,
        evidence: String? = nil,
        noteId: UUID? = nil,
        quoteId: UUID? = nil,
        isUserCreated: Bool = false
    ) throws -> KnowledgeEdge {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        // Check for existing edge
        let sourceId = source.id
        let targetId = target.id
        let relType = relationship.rawValue

        let descriptor = FetchDescriptor<KnowledgeEdge>(
            predicate: #Predicate<KnowledgeEdge> { edge in
                edge.sourceNode?.id == sourceId &&
                edge.targetNode?.id == targetId &&
                edge.relationshipType == relType
            }
        )

        if let existing = try context.fetch(descriptor).first {
            // Strengthen existing edge
            if let evidence = evidence {
                existing.addEvidence(evidence, noteId: noteId, quoteId: quoteId)
            }
            return existing
        }

        // Create new edge
        let edge = KnowledgeEdge(
            source: source,
            target: target,
            relationship: relationship,
            weight: weight,
            confidence: confidence,
            isUserCreated: isUserCreated
        )

        if let evidence = evidence {
            edge.addEvidence(evidence, noteId: noteId, quoteId: quoteId)
        }

        context.insert(edge)

        #if DEBUG
        print("📊 Created edge: \(source.label) --[\(relationship.displayName)]--> \(target.label)")
        #endif

        return edge
    }

    /// Find all edges connecting to a node
    func findEdges(
        for node: KnowledgeNode,
        direction: EdgeDirection = .both,
        relationshipTypes: [KnowledgeEdge.EdgeType]? = nil
    ) throws -> [KnowledgeEdge] {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        let nodeId = node.id

        var edges: [KnowledgeEdge] = []

        if direction == .outgoing || direction == .both {
            let outDescriptor = FetchDescriptor<KnowledgeEdge>(
                predicate: #Predicate<KnowledgeEdge> { $0.sourceNode?.id == nodeId }
            )
            edges.append(contentsOf: try context.fetch(outDescriptor))
        }

        if direction == .incoming || direction == .both {
            let inDescriptor = FetchDescriptor<KnowledgeEdge>(
                predicate: #Predicate<KnowledgeEdge> { $0.targetNode?.id == nodeId }
            )
            edges.append(contentsOf: try context.fetch(inDescriptor))
        }

        // Filter by relationship type if specified
        if let types = relationshipTypes {
            let typeStrings = types.map { $0.rawValue }
            edges = edges.filter { typeStrings.contains($0.relationshipType) }
        }

        return edges
    }

    // MARK: - Graph Traversal

    /// Find all nodes connected to a starting node within N hops
    func traverse(
        from node: KnowledgeNode,
        maxDepth: Int = 2,
        relationshipTypes: [KnowledgeEdge.EdgeType]? = nil
    ) throws -> [TraversalResult] {
        var visited: Set<UUID> = [node.id]
        var results: [TraversalResult] = []
        var queue: [(node: KnowledgeNode, depth: Int, path: [KnowledgeEdge])] = [(node, 0, [])]

        while !queue.isEmpty {
            let (currentNode, depth, path) = queue.removeFirst()

            if depth > 0 {
                results.append(TraversalResult(
                    node: currentNode,
                    depth: depth,
                    path: path
                ))
            }

            if depth < maxDepth {
                let edges = try findEdges(for: currentNode, relationshipTypes: relationshipTypes)

                for edge in edges {
                    let neighbor: KnowledgeNode?
                    if edge.sourceNode?.id == currentNode.id {
                        neighbor = edge.targetNode
                    } else {
                        neighbor = edge.sourceNode
                    }

                    guard let neighbor = neighbor, !visited.contains(neighbor.id) else { continue }

                    visited.insert(neighbor.id)
                    queue.append((neighbor, depth + 1, path + [edge]))
                }
            }
        }

        return results.sorted { $0.depth < $1.depth }
    }

    /// Find paths between two nodes
    func findPaths(
        from source: KnowledgeNode,
        to target: KnowledgeNode,
        maxDepth: Int = 3
    ) throws -> [[KnowledgeEdge]] {
        var paths: [[KnowledgeEdge]] = []
        var visited: Set<UUID> = []

        func dfs(node: KnowledgeNode, path: [KnowledgeEdge], depth: Int) throws {
            if node.id == target.id {
                paths.append(path)
                return
            }

            if depth >= maxDepth { return }

            visited.insert(node.id)

            let edges = try findEdges(for: node)
            for edge in edges {
                let neighbor: KnowledgeNode?
                if edge.sourceNode?.id == node.id {
                    neighbor = edge.targetNode
                } else {
                    neighbor = edge.sourceNode
                }

                guard let neighbor = neighbor, !visited.contains(neighbor.id) else { continue }
                try dfs(node: neighbor, path: path + [edge], depth: depth + 1)
            }

            visited.remove(node.id)
        }

        try dfs(node: source, path: [], depth: 0)
        return paths
    }

    // MARK: - Theme & Concept Analysis

    /// Get all themes across all books, ranked by engagement
    func getTopThemes(limit: Int = 20) throws -> [KnowledgeNode] {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        let themeType = KnowledgeNode.NodeType.theme.rawValue
        let descriptor = FetchDescriptor<KnowledgeNode>(
            predicate: #Predicate<KnowledgeNode> { $0.nodeType == themeType },
            sortBy: [SortDescriptor(\.mentionCount, order: .reverse)]
        )

        var themes = try context.fetch(descriptor)
        themes.sort { $0.engagementScore > $1.engagementScore }

        return Array(themes.prefix(limit))
    }

    /// Find themes shared between two or more books
    func findSharedThemes(bookIds: [String]) throws -> [KnowledgeNode] {
        guard bookIds.count >= 2 else { return [] }

        let allThemes = try getTopThemes(limit: 100)

        return allThemes.filter { theme in
            let bookOrigins = Set(theme.sourceBooks.map { $0.id })
            let matchCount = bookIds.filter { bookOrigins.contains($0) }.count
            return matchCount >= 2
        }
    }

    /// Find what connects two books
    func findConnections(
        between book1Id: String,
        and book2Id: String
    ) throws -> [ConnectionResult] {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        var connections: [ConnectionResult] = []

        // Find all nodes associated with both books
        let descriptor = FetchDescriptor<KnowledgeNode>()
        let allNodes = try context.fetch(descriptor)

        for node in allNodes {
            let bookIds = node.sourceBooks.map { $0.id }
            if bookIds.contains(book1Id) && bookIds.contains(book2Id) {
                connections.append(ConnectionResult(
                    node: node,
                    connectionType: node.type,
                    evidence: gatherEvidence(for: node, bookIds: [book1Id, book2Id])
                ))
            }
        }

        return connections.sorted { $0.node.engagementScore > $1.node.engagementScore }
    }

    // MARK: - Statistics

    /// Get graph statistics
    func getStatistics() throws -> GraphStatistics {
        guard let context = modelContext else {
            throw KnowledgeGraphError.notConfigured
        }

        let nodeDescriptor = FetchDescriptor<KnowledgeNode>()
        let allNodes = try context.fetch(nodeDescriptor)

        let edgeDescriptor = FetchDescriptor<KnowledgeEdge>()
        let allEdges = try context.fetch(edgeDescriptor)

        var nodesByType: [KnowledgeNode.NodeType: Int] = [:]
        for node in allNodes {
            nodesByType[node.type, default: 0] += 1
        }

        var edgesByType: [KnowledgeEdge.EdgeType: Int] = [:]
        for edge in allEdges {
            edgesByType[edge.relationship, default: 0] += 1
        }

        return GraphStatistics(
            totalNodes: allNodes.count,
            totalEdges: allEdges.count,
            nodesByType: nodesByType,
            edgesByType: edgesByType,
            nodesWithEmbeddings: allNodes.filter { $0.hasEmbedding }.count
        )
    }

    // MARK: - Embedding Generation

    /// Generate a 300-dimensional embedding for text
    func generateEmbedding(for text: String) -> [Float]? {
        guard let model = embeddingModel else { return nil }

        // For multi-word phrases, average the word embeddings
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard !words.isEmpty else { return nil }

        var embeddings: [[Double]] = []
        for word in words {
            if let vector = model.vector(for: word) {
                embeddings.append(vector)
            }
        }

        guard !embeddings.isEmpty else { return nil }

        // Average the embeddings
        let dimension = embeddings[0].count
        var averaged = [Double](repeating: 0.0, count: dimension)

        for embedding in embeddings {
            for i in 0..<dimension {
                averaged[i] += embedding[i]
            }
        }

        let count = Double(embeddings.count)
        return averaged.map { Float($0 / count) }
    }

    /// Calculate cosine similarity between two embeddings
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0

        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        vDSP_dotpr(a, 1, a, 1, &normA, vDSP_Length(a.count))
        vDSP_dotpr(b, 1, b, 1, &normB, vDSP_Length(b.count))

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    // MARK: - Cache Management

    /// Clear the node cache
    func clearCache() {
        nodeCache.removeAll()
        lastCacheRefresh = .distantPast
    }

    /// Refresh the cache from database
    func refreshCache() throws {
        guard let context = modelContext else { return }

        nodeCache.removeAll()

        let descriptor = FetchDescriptor<KnowledgeNode>()
        let allNodes = try context.fetch(descriptor)

        for node in allNodes {
            let cacheKey = "\(node.nodeType):\(node.normalizedLabel)"
            nodeCache[cacheKey] = node
        }

        lastCacheRefresh = Date()
    }

    // MARK: - Helpers

    private func gatherEvidence(for node: KnowledgeNode, bookIds: [String]) -> [String] {
        var evidence: [String] = []

        // Get quotes mentioning this entity
        for quote in node.sourceQuotes {
            if let text = quote.text, let bookId = quote.book?.id, bookIds.contains(bookId) {
                let preview = String(text.prefix(100))
                evidence.append("\"\(preview)...\"")
            }
        }

        // Get notes mentioning this entity
        for note in node.sourceNotes {
            if let bookId = note.book?.id, bookIds.contains(bookId) {
                if let content = note.content, !content.isEmpty {
                    let preview = String(content.prefix(100))
                    evidence.append(preview)
                }
            }
        }

        return Array(evidence.prefix(5))
    }
}

// MARK: - Supporting Types

extension KnowledgeGraphService {
    enum EdgeDirection {
        case incoming
        case outgoing
        case both
    }

    struct TraversalResult {
        let node: KnowledgeNode
        let depth: Int
        let path: [KnowledgeEdge]

        var pathDescription: String {
            path.map { $0.relationship.displayName }.joined(separator: " → ")
        }
    }

    struct ConnectionResult {
        let node: KnowledgeNode
        let connectionType: KnowledgeNode.NodeType
        let evidence: [String]
    }

    struct GraphStatistics {
        let totalNodes: Int
        let totalEdges: Int
        let nodesByType: [KnowledgeNode.NodeType: Int]
        let edgesByType: [KnowledgeEdge.EdgeType: Int]
        let nodesWithEmbeddings: Int

        var summary: String {
            """
            Knowledge Graph Statistics:
            - Total Nodes: \(totalNodes)
            - Total Edges: \(totalEdges)
            - Nodes with Embeddings: \(nodesWithEmbeddings)
            - Node Types: \(nodesByType.map { "\($0.key.displayName): \($0.value)" }.joined(separator: ", "))
            """
        }
    }
}

// MARK: - Errors

enum KnowledgeGraphError: Error, LocalizedError {
    case notConfigured
    case nodeNotFound(String)
    case invalidRelationship
    case embeddingFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Knowledge Graph Service not configured with ModelContext"
        case .nodeNotFound(let label):
            return "Node not found: \(label)"
        case .invalidRelationship:
            return "Invalid relationship between node types"
        case .embeddingFailed:
            return "Failed to generate embedding"
        }
    }
}
