import SwiftData
import SwiftUI

extension ModelContainer {
    static let appContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            Quote.self,
            Note.self,
            AISession.self,
            AIMessage.self,
            UsageTracking.self,
            ReadingSession.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic // Enables iCloud backup
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    static let previewContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            Quote.self,
            Note.self,
            AISession.self,
            AIMessage.self,
            UsageTracking.self,
            ReadingSession.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Add sample data for previews
            let context = container.mainContext
            
            let sampleBook = Book(
                title: "The Great Gatsby",
                author: "F. Scott Fitzgerald",
                genre: "Classic Fiction",
                publicationYear: 1925,
                totalPages: 180
            )
            context.insert(sampleBook)
            
            let sampleQuote = Quote(
                text: "So we beat on, boats against the current, borne back ceaselessly into the past.",
                book: sampleBook,
                pageNumber: 180,
                chapter: "Chapter 9"
            )
            context.insert(sampleQuote)
            
            let sampleNote = Note(
                title: "Theme of the American Dream",
                content: "The novel explores the corruption of the American Dream through Gatsby's pursuit of Daisy.",
                book: sampleBook,
                tags: ["themes", "analysis"]
            )
            context.insert(sampleNote)
            
            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()
}

// Migration support
enum ModelMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        []
    }
}

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Book.self, Quote.self, Note.self, AISession.self, AIMessage.self, UsageTracking.self, ReadingSession.self]
    }
}