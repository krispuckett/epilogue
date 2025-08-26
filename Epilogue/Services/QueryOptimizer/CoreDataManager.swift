import CoreData
import Foundation

class CoreDataManager {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Epilogue")
        
        // Enable iCloud sync for cache data
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Configure for CloudKit if available
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.epilogue.app"
            )
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                print("Core Data failed to load: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // MARK: - Save Context
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    // MARK: - Background Context
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    // MARK: - Cache Management
    
    func cleanupOldCache(olderThan days: Int = 7) {
        let context = viewContext
        let request = CachedQuery.fetchRequest()
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        request.predicate = NSPredicate(format: "lastAccessedAt < %@", cutoffDate as NSDate)
        
        do {
            let oldQueries = try context.fetch(request)
            for query in oldQueries {
                context.delete(query)
            }
            save()
        } catch {
            print("Error cleaning up cache: \(error)")
        }
    }
    
    func getCacheSize() -> Int {
        let request = CachedQuery.fetchRequest()
        return (try? viewContext.count(for: request)) ?? 0
    }
    
    // MARK: - Analytics Helpers
    
    func getTodaysAnalytics() -> QueryAnalytics? {
        let request = QueryAnalytics.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.startOfDay(for: Date()) as NSDate
        )
        request.fetchLimit = 1
        
        return try? viewContext.fetch(request).first
    }
    
    func getAnalytics(for dateRange: DateInterval) -> [QueryAnalytics] {
        let request = QueryAnalytics.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            dateRange.start as NSDate,
            dateRange.end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        return (try? viewContext.fetch(request)) ?? []
    }
    
    // MARK: - Quota Management
    
    func getCurrentQuota() -> UserQuota? {
        let request = UserQuota.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@",
            Calendar.current.startOfDay(for: Date()) as NSDate
        )
        request.fetchLimit = 1
        
        return try? viewContext.fetch(request).first
    }
    
    func createOrUpdateQuota(isPro: Bool, queriesUsed: Int) {
        let context = viewContext
        
        let quota: UserQuota
        if let existing = getCurrentQuota() {
            quota = existing
        } else {
            quota = UserQuota(context: context)
            quota.id = UUID()
            quota.date = Date()
            quota.lastResetDate = Date()
        }
        
        quota.isPro = isPro
        quota.freeQueriesUsed = Int32(queriesUsed)
        quota.totalQueriesAllTime += 1
        
        save()
    }
    
    // MARK: - Similar Queries
    
    func findSimilarQueries(to queryHash: String, limit: Int = 5) -> [CachedQuery] {
        let request = CachedQuery.fetchRequest()
        request.fetchLimit = limit
        request.sortDescriptors = [NSSortDescriptor(key: "confidence", ascending: false)]
        
        // This would ideally use a more sophisticated similarity search
        // For now, we'll return recent queries
        request.sortDescriptors = [NSSortDescriptor(key: "lastAccessedAt", ascending: false)]
        
        return (try? viewContext.fetch(request)) ?? []
    }
    
    // MARK: - Migration
    
    func performMigrationIfNeeded() {
        // Check for migration needs
        let version = UserDefaults.standard.integer(forKey: "CoreDataSchemaVersion")
        let currentVersion = 1
        
        if version < currentVersion {
            // Perform migration
            migrateToCurrent(from: version)
            UserDefaults.standard.set(currentVersion, forKey: "CoreDataSchemaVersion")
        }
    }
    
    private func migrateToCurrent(from oldVersion: Int) {
        // Handle migrations between versions
        switch oldVersion {
        case 0:
            // Initial setup, no migration needed
            break
        default:
            break
        }
    }
    
    // MARK: - Batch Operations
    
    func batchInsertCachedQueries(_ queries: [(query: String, response: String, bookId: UUID?)]) {
        performBackgroundTask { context in
            for item in queries {
                let cached = CachedQuery(context: context)
                cached.id = UUID()
                cached.query = item.query
                cached.queryHash = CachedQuery.generateHash(for: item.query, bookId: item.bookId)
                cached.response = item.response
                cached.bookId = item.bookId
                cached.createdAt = Date()
                cached.lastAccessedAt = Date()
            }
            
            do {
                try context.save()
            } catch {
                print("Batch insert failed: \(error)")
            }
        }
    }
    
    // MARK: - Export/Import
    
    func exportCache() -> Data? {
        let request = CachedQuery.fetchRequest()
        guard let queries = try? viewContext.fetch(request) else { return nil }
        
        let exportData = queries.map { query in
            [
                "query": query.query ?? "",
                "response": query.response ?? "",
                "bookId": query.bookId?.uuidString ?? "",
                "createdAt": query.createdAt?.timeIntervalSince1970 ?? 0
            ]
        }
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    func importCache(from data: Data) {
        guard let importData = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        
        performBackgroundTask { context in
            for item in importData {
                let cached = CachedQuery(context: context)
                cached.id = UUID()
                cached.query = item["query"] as? String
                cached.response = item["response"] as? String
                
                if let bookIdString = item["bookId"] as? String,
                   let bookId = UUID(uuidString: bookIdString) {
                    cached.bookId = bookId
                }
                
                if let timestamp = item["createdAt"] as? TimeInterval {
                    cached.createdAt = Date(timeIntervalSince1970: timestamp)
                }
                
                cached.lastAccessedAt = Date()
            }
            
            try? context.save()
        }
    }
}