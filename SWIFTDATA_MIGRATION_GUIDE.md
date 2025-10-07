# SwiftData Schema Migration Guide for Epilogue

## ⚠️ CRITICAL: Never Delete User Data

This guide ensures we NEVER delete user data when updating SwiftData models.

## The Problem That Happened

When we added `isAmbientSession` and `lastInteraction` to `ReadingSession` without proper migration, SwiftData **deleted all user data** including:
- All notes
- All reading sessions
- All captured quotes
- Everything

This is **UNACCEPTABLE** and would destroy user trust completely.

## The Solution: Versioned Schemas

We now use `VersionedSchema` and `SchemaMigrationPlan` to safely evolve our data models.

### Current Schema Version: V2

Location: `/Models/SwiftData/SchemaVersioning.swift`

```swift
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
            ReadingSession.self  // ← MUST include ALL models!
        ]
    }
}
```

## How to Add a New Field Safely

### ✅ SAFE: Add Field with Default Value

```swift
@Model
final class ReadingSession {
    var startDate: Date
    var endDate: Date?
    var newField: String = "default"  // ← Safe! Has default value
    var optionalField: Int?            // ← Safe! Optional
}
```

**No migration needed!** SwiftData will automatically add the field with the default value to existing records.

### ❌ UNSAFE: Add Required Field Without Default

```swift
@Model
final class ReadingSession {
    var startDate: Date
    var endDate: Date?
    var newField: String  // ← DANGEROUS! No default - will delete data!
}
```

**DON'T DO THIS!** This will cause data loss.

## How to Make Breaking Changes

If you MUST change a field type or remove a field:

### Step 1: Create New Schema Version

```swift
enum EpilogueSchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            BookModel.self,
            // ... all other models
            ReadingSession.self
        ]
    }
}
```

### Step 2: Update Migration Plan

```swift
enum EpilogueMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            EpilogueSchemaV1.self,
            EpilogueSchemaV2.self,
            EpilogueSchemaV3.self  // ← Add new version
        ]
    }

    static var stages: [MigrationStage] {
        [
            migrateV1toV2,
            migrateV2toV3  // ← Add new migration
        ]
    }

    static let migrateV2toV3 = MigrationStage.custom(
        fromVersion: EpilogueSchemaV2.self,
        toVersion: EpilogueSchemaV3.self,
        willMigrate: { context in
            print("🔄 Migrating V2 → V3...")

            // Custom migration logic here
            // Example: Convert field types
            let descriptor = FetchDescriptor<ReadingSession>()
            let sessions = try context.fetch(descriptor)

            for session in sessions {
                // Transform data as needed
                session.newField = transformOldField(session.oldField)
            }

            try context.save()
        },
        didMigrate: { context in
            print("✅ Migration V2 → V3 complete")

            // Verify data integrity
            let count = try context.fetchCount(FetchDescriptor<ReadingSession>())
            print("📊 Verified \(count) sessions after migration")
        }
    )
}
```

### Step 3: Test Migration Locally

1. Create test data in V2
2. Build and run with V3 schema
3. Verify all data is preserved
4. Check console logs for migration success

## Checklist Before Any Model Change

- [ ] Does this change require a migration?
- [ ] If adding a field, does it have a default value or is it optional?
- [ ] Have I incremented the schema version?
- [ ] Have I added the migration to `EpilogueMigrationPlan`?
- [ ] Have I tested the migration with real data?
- [ ] Have I verified data count before/after migration?

## Common Mistakes to Avoid

### ❌ Forgetting to Include Model in Schema

```swift
// BAD - ReadingSession missing!
static var models: [any PersistentModel.Type] {
    [
        BookModel.self,
        CapturedNote.self
        // ← Where's ReadingSession???
    ]
}
```

This will **delete all ReadingSession data** silently.

### ❌ Modifying Existing Field Type

```swift
// DON'T DO THIS
var duration: TimeInterval  →  var duration: Int
```

Create a new schema version with migration instead.

### ❌ Removing Field Without Migration

```swift
// DON'T DO THIS
// var oldField: String  ← Just deleted it
```

Mark as deprecated first, then remove in next major version with migration.

## Testing Migrations

### Manual Testing Steps

1. **Create test data in current schema**
   ```swift
   // Add books, notes, sessions in simulator
   ```

2. **Make your schema change**
   ```swift
   // Update model, create V3, add migration
   ```

3. **Clean and rebuild**
   ```bash
   xcodebuild clean build
   ```

4. **Verify in console**
   ```
   🔄 Starting migration from V2 to V3...
   ✅ Migration complete - all data preserved
   📊 ReadingSessions after migration: 42
   ```

5. **Check data in app**
   - Open Sessions tab
   - Verify all sessions present
   - Check notes, books, quotes

### Automated Testing (TODO)

Create unit tests for migrations:

```swift
func testMigrationV2toV3PreservesData() async throws {
    // Setup V2 container with test data
    // Perform migration to V3
    // Assert data count matches
    // Assert data integrity
}
```

## CloudKit Considerations

- Schema changes sync automatically via CloudKit
- All devices must have app version that understands new schema
- Plan migrations carefully for production users
- Consider backward compatibility for users who don't update immediately

## Emergency Data Recovery

If data loss occurs:

1. **Stop immediately** - don't make more changes
2. Check CloudKit dashboard for backups
3. Look for local `.store-shm` and `.store-wal` files
4. Restore from Time Machine/iCloud backup
5. Document what went wrong
6. Add tests to prevent recurrence

## Resources

- [SwiftData Migration Documentation](https://developer.apple.com/documentation/swiftdata/migrating-data-with-swiftdata)
- [WWDC23: Model your schema with SwiftData](https://developer.apple.com/videos/play/wwdc2023/10195/)

## Questions?

Before making ANY schema change, ask:

1. Will this delete user data?
2. Do I need a migration?
3. Have I tested this?

**When in doubt, DON'T DEPLOY.**