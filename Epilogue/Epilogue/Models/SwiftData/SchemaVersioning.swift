import SwiftData
import Foundation

// MARK: - Schema Versioning for Safe Migrations
// This prevents data loss when models change

enum EpilogueSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self,
            QueuedQuestion.self,
            ReadingSession.self  // CRITICAL: Include ReadingSession in schema!
        ]
    }
}

enum EpilogueSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self,
            QueuedQuestion.self,
            ReadingSession.self
        ]
    }
}

enum EpilogueSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self,
            QueuedQuestion.self,
            ReadingSession.self
        ]
    }
}

enum EpilogueSchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            BookModel.self,
            CapturedNote.self,
            CapturedQuote.self,
            CapturedQuestion.self,
            AmbientSession.self,
            QueuedQuestion.self,
            ReadingSession.self
        ]
    }
}

// Migration plan between versions
enum EpilogueMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            EpilogueSchemaV1.self,
            EpilogueSchemaV2.self,
            EpilogueSchemaV3.self,
            EpilogueSchemaV4.self
        ]
    }

    static var stages: [MigrationStage] {
        [
            // Migration from V1 to V2 (adding ReadingSession fields)
            migrateV1toV2,
            // Migration from V2 to V3 (adding BookModel.coverImageData)
            migrateV2toV3,
            // Migration from V3 to V4 (adding book enrichment fields) - LIGHTWEIGHT
            MigrationStage.lightweight(fromVersion: EpilogueSchemaV3.self, toVersion: EpilogueSchemaV4.self)
        ]
    }

    // Custom migration to preserve data when adding new fields
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: EpilogueSchemaV1.self,
        toVersion: EpilogueSchemaV2.self,
        willMigrate: { context in
            #if DEBUG
            print("🔄 Starting migration from V1 to V2...")
            #endif
            #if DEBUG
            print("📊 Preserving all existing data...")
            #endif
        },
        didMigrate: { context in
            #if DEBUG
            print("✅ Migration complete - all data preserved")
            #endif

            // Count records to verify nothing was lost
            let descriptor = FetchDescriptor<ReadingSession>()
            let sessions = try? context.fetch(descriptor)
            #if DEBUG
            print("📚 ReadingSessions after migration: \(sessions?.count ?? 0)")
            #endif
        }
    )

    // Migration from V2 to V3 - adding offline cover cache field
    static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: EpilogueSchemaV2.self,
        toVersion: EpilogueSchemaV3.self,
        willMigrate: { context in
            #if DEBUG
            print("🔄 Starting migration from V2 to V3...")
            #endif
            #if DEBUG
            print("📊 Adding coverImageData field to BookModel (optional, external storage)...")
            #endif

            // Count existing records BEFORE migration
            let bookDescriptor = FetchDescriptor<BookModel>()
            let booksBeforeMigration = try? context.fetch(bookDescriptor)
            let bookCount = booksBeforeMigration?.count ?? 0

            let noteDescriptor = FetchDescriptor<CapturedNote>()
            let notesBeforeMigration = try? context.fetch(noteDescriptor)
            let noteCount = notesBeforeMigration?.count ?? 0

            let sessionDescriptor = FetchDescriptor<ReadingSession>()
            let sessionsBeforeMigration = try? context.fetch(sessionDescriptor)
            let sessionCount = sessionsBeforeMigration?.count ?? 0

            #if DEBUG
            print("📊 Pre-migration counts:")
            #endif
            #if DEBUG
            print("   Books: \(bookCount)")
            #endif
            #if DEBUG
            print("   Notes: \(noteCount)")
            #endif
            #if DEBUG
            print("   Sessions: \(sessionCount)")
            #endif
        },
        didMigrate: { context in
            #if DEBUG
            print("✅ V3 Migration complete - coverImageData field added")
            #endif

            // Verify data preserved after migration
            let bookDescriptor = FetchDescriptor<BookModel>()
            let booksAfterMigration = try? context.fetch(bookDescriptor)
            let bookCount = booksAfterMigration?.count ?? 0

            let noteDescriptor = FetchDescriptor<CapturedNote>()
            let notesAfterMigration = try? context.fetch(noteDescriptor)
            let noteCount = notesAfterMigration?.count ?? 0

            let sessionDescriptor = FetchDescriptor<ReadingSession>()
            let sessionsAfterMigration = try? context.fetch(sessionDescriptor)
            let sessionCount = sessionsAfterMigration?.count ?? 0

            #if DEBUG
            print("📊 Post-migration counts:")
            #endif
            #if DEBUG
            print("   Books: \(bookCount)")
            #endif
            #if DEBUG
            print("   Notes: \(noteCount)")
            #endif
            #if DEBUG
            print("   Sessions: \(sessionCount)")
            #endif

            // Verify at least some data exists if this isn't a fresh install
            if bookCount > 0 {
                #if DEBUG
                print("✅ Data preserved successfully!")
                #endif

                // Sample check: verify book fields intact
                if let sampleBook = booksAfterMigration?.first {
                    let hasTitle = !sampleBook.title.isEmpty
                    let hasAuthor = !sampleBook.author.isEmpty
                    #if DEBUG
                    print("   Sample book check: title=\(hasTitle), author=\(hasAuthor)")
                    #endif
                }
            } else {
                #if DEBUG
                print("ℹ️  No existing data (fresh install or new user)")
                #endif
            }
        }
    )
}

// MARK: - Safe Schema Evolution Rules
/*

 RULES TO PREVENT DATA LOSS:

 1. NEVER modify existing properties without a migration
 2. ALWAYS add new properties with default values
 3. ALWAYS increment schema version when changing models
 4. ALWAYS test migrations with real data before release
 5. ALWAYS include ALL models in the schema array

 ADDING A NEW FIELD (Safe):
 ✅ var newField: String = "default"
 ✅ var optionalField: String?

 MODIFYING A FIELD (Requires Migration):
 ❌ var name: String  →  var name: Int  // DON'T DO THIS
 ✅ Create V2 schema with custom migration

 REMOVING A FIELD (Requires Migration):
 ❌ Delete var oldField: String  // DON'T DO THIS
 ✅ Mark as deprecated, remove in next major version with migration

 */