import Foundation
import CoreData
import CryptoKit

@objc(CachedQuery)
public class CachedQuery: NSManagedObject {
    
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        lastAccessedAt = Date()
        accessCount = 1
    }
    
    func updateAccess() {
        lastAccessedAt = Date()
        accessCount += 1
    }
    
    static func generateHash(for query: String, bookId: UUID? = nil) -> String {
        let input = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) + (bookId?.uuidString ?? "")
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    var cacheAge: TimeInterval {
        Date().timeIntervalSince(createdAt ?? Date())
    }
    
    var isStale: Bool {
        cacheAge > 7 * 24 * 60 * 60 // 7 days
    }
}

@objc(CachedQuery)
extension CachedQuery {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CachedQuery> {
        return NSFetchRequest<CachedQuery>(entityName: "CachedQuery")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var query: String?
    @NSManaged public var queryHash: String?
    @NSManaged public var response: String?
    @NSManaged public var bookId: UUID?
    @NSManaged public var bookTitle: String?
    @NSManaged public var contextUsed: String?
    @NSManaged public var tokensUsed: Int32
    @NSManaged public var responseTime: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var lastAccessedAt: Date?
    @NSManaged public var accessCount: Int32
    @NSManaged public var queryType: String?
    @NSManaged public var embedding: Data?
    @NSManaged public var confidence: Double
    @NSManaged public var similarQueries: NSSet?
}

// MARK: Generated accessors for similarQueries
extension CachedQuery {
    
    @objc(addSimilarQueriesObject:)
    @NSManaged public func addToSimilarQueries(_ value: SimilarQuery)
    
    @objc(removeSimilarQueriesObject:)
    @NSManaged public func removeFromSimilarQueries(_ value: SimilarQuery)
    
    @objc(addSimilarQueries:)
    @NSManaged public func addToSimilarQueries(_ values: NSSet)
    
    @objc(removeSimilarQueries:)
    @NSManaged public func removeFromSimilarQueries(_ values: NSSet)
}