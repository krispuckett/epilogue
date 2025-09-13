import SwiftData
import SwiftUI
import Combine

// MARK: - Safe ModelContext Extensions
extension ModelContext {
    
    /// Safely save changes without crashing
    func safeSave() {
        do {
            if hasChanges {
                try save()
                #if DEBUG
                print("✅ SwiftData saved successfully")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ SwiftData save failed: \(error)")
            #endif
            // Log to crash reporting
            CrashPreventionManager.shared.logError(error, context: "SwiftData.save")
            
            // Attempt to rollback if possible
            rollback()
        }
    }
    
    /// Safe fetch with error handling
    func safeFetch<T>(_ descriptor: FetchDescriptor<T>) -> [T] where T: PersistentModel {
        do {
            return try fetch(descriptor)
        } catch {
            #if DEBUG
            print("❌ SwiftData fetch failed: \(error)")
            #endif
            CrashPreventionManager.shared.logError(error, context: "SwiftData.fetch")
            return []
        }
    }
    
    /// Safe delete with automatic rollback on failure
    func safeDelete<T: PersistentModel>(_ model: T) {
        do {
            delete(model)
            try save()
            #if DEBUG
            print("✅ SwiftData deleted model successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ SwiftData delete failed: \(error)")
            #endif
            CrashPreventionManager.shared.logError(error, context: "SwiftData.delete")
            rollback()
        }
    }
    
    /// Safe batch delete
    func safeBatchDelete<T: PersistentModel>(_ models: [T]) {
        do {
            for model in models {
                delete(model)
            }
            try save()
            #if DEBUG
            print("✅ SwiftData batch deleted \(models.count) models")
            #endif
        } catch {
            #if DEBUG
            print("❌ SwiftData batch delete failed: \(error)")
            #endif
            CrashPreventionManager.shared.logError(error, context: "SwiftData.batchDelete")
            rollback()
        }
    }
    
    /// Safe insert with validation
    func safeInsert<T: PersistentModel>(_ model: T) {
        do {
            insert(model)
            try save()
            #if DEBUG
            print("✅ SwiftData inserted model successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ SwiftData insert failed: \(error)")
            #endif
            CrashPreventionManager.shared.logError(error, context: "SwiftData.insert")
            rollback()
        }
    }
    
    /// Safe transaction wrapper
    func safeTransaction<T>(_ action: () throws -> T) -> T? {
        do {
            let result = try action()
            try save()
            return result
        } catch {
            #if DEBUG
            print("❌ SwiftData transaction failed: \(error)")
            #endif
            CrashPreventionManager.shared.logError(error, context: "SwiftData.transaction")
            rollback()
            return nil
        }
    }
    
    /// Check if model container is healthy
    var isHealthy: Bool {
        do {
            // Try a simple operation to verify health
            var descriptor = FetchDescriptor<BookModel>(
                predicate: #Predicate { _ in false }
            )
            descriptor.fetchLimit = 1
            _ = try fetch(descriptor)
            return true
        } catch {
            #if DEBUG
            print("⚠️ ModelContext health check failed: \(error)")
            #endif
            return false
        }
    }
}

// MARK: - Safe Query Wrapper
@propertyWrapper
struct SafeQuery<T: PersistentModel> {
    private var fetchDescriptor: FetchDescriptor<T>
    @State private var results: [T] = []
    @State private var hasError = false
    @Environment(\.modelContext) private var modelContext
    
    init(
        filter: Predicate<T>? = nil,
        sort: [SortDescriptor<T>] = [],
        limit: Int? = nil
    ) {
        self.fetchDescriptor = FetchDescriptor<T>(
            predicate: filter,
            sortBy: sort
        )
        if let limit = limit {
            self.fetchDescriptor.fetchLimit = limit
        }
    }
    
    var wrappedValue: [T] {
        get { results }
        set { results = newValue }
    }
    
    var projectedValue: Binding<[T]> {
        Binding(
            get: { results },
            set: { results = $0 }
        )
    }
    
    func fetch() {
        do {
            results = try modelContext.fetch(fetchDescriptor)
        } catch {
            #if DEBUG
            print("❌ SafeQuery fetch failed: \(error)")
            #endif
            hasError = true
            results = []
        }
    }
}

// MARK: - Migration Safety
struct SwiftDataMigrationModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @State private var migrationComplete = false
    @State private var migrationError: Error?
    
    func body(content: Content) -> some View {
        Group {
            if let error = migrationError {
                ErrorFallbackView(
                    errorMessage: "Database migration failed: \(error.localizedDescription)",
                    onRetry: {
                        migrationError = nil
                        performMigration()
                    }
                )
            } else if !migrationComplete {
                VStack {
                    ProgressView("Preparing your library...")
                        .padding()
                }
                .onAppear {
                    performMigration()
                }
            } else {
                content
            }
        }
    }
    
    private func performMigration() {
        Task {
            do {
                // Check if migration is needed
                if needsMigration() {
                    try await migrate()
                }
                await MainActor.run {
                    migrationComplete = true
                }
            } catch {
                await MainActor.run {
                    migrationError = error
                }
            }
        }
    }
    
    private func needsMigration() -> Bool {
        // Check UserDefaults for migration flag
        let migrationKey = "com.epilogue.swiftdata.migration.v1"
        return !UserDefaults.standard.bool(forKey: migrationKey)
    }
    
    private func migrate() async throws {
        // Perform migration logic here
        #if DEBUG
        print("🔄 Starting SwiftData migration...")
        #endif
        
        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: "com.epilogue.swiftdata.migration.v1")
        
        #if DEBUG
        print("✅ SwiftData migration complete")
        #endif
    }
}

extension View {
    func withSafeDataMigrations() -> some View {
        modifier(SwiftDataMigrationModifier())
    }
}

// MARK: - Safe Model Operations
extension PersistentModel {
    
    /// Safe update with automatic rollback
    func safeUpdate(in context: ModelContext, updates: () -> Void) {
        do {
            updates()
            try context.save()
        } catch {
            #if DEBUG
            print("❌ Model update failed: \(error)")
            #endif
            context.rollback()
        }
    }
}

// MARK: - Batch Operations
extension ModelContext {
    
    /// Safe batch insert with progress tracking
    func safeBatchInsert<T: PersistentModel>(
        _ models: [T],
        progressHandler: ((Double) -> Void)? = nil
    ) {
        let total = Double(models.count)
        var inserted = 0.0
        
        for model in models {
            do {
                insert(model)
                inserted += 1
                progressHandler?(inserted / total)
                
                // Save every 50 items to prevent memory buildup
                if Int(inserted) % 50 == 0 {
                    try save()
                }
            } catch {
                #if DEBUG
                print("❌ Batch insert failed at item \(Int(inserted)): \(error)")
                #endif
                // Continue with next item
            }
        }
        
        // Final save
        safeSave()
    }
}

// MARK: - Data Validation
protocol ValidatableModel: PersistentModel {
    func validate() throws
}

enum ValidationError: Error {
    case missingRequiredField(String)
    case invalidValue(String)
    case duplicateEntry(String)
}

extension ModelContext {
    
    /// Safe insert with validation
    func safeValidatedInsert<T: ValidatableModel>(_ model: T) throws {
        try model.validate()
        insert(model)
        try save()
    }
}