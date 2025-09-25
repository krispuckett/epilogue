# Data Migration Service - Implementation Notes

## Overview
The DataMigrationService handles the migration from the old SwiftData schema to the new schema. This was necessary because the app evolved from using direct SwiftData models to a hybrid approach with both struct-based models and SwiftData models.

## Key Changes Made

### 1. Created LegacyModels.swift
- Defined all the old SwiftData models with "Legacy" prefix to avoid naming conflicts
- Models included: LegacyBook, LegacyQuote, LegacyNote, LegacyAISession, LegacyAIMessage, LegacyReadingSession, LegacyUsageTracking

### 2. Updated DataMigrationService.swift
- Changed all references from old model names (Book, Quote, etc.) to legacy model names (LegacyBook, LegacyQuote, etc.)
- Fixed import source from `.import` to `.import_` (underscore required because `import` is a reserved keyword)

### 3. Model Mappings

#### Old Schema → New Schema
- `LegacyBook` → `BookModel`
- `LegacyQuote` → `CapturedQuote`
- `LegacyNote` → `CapturedNote`
- `LegacyAISession` → `AmbientSession` (with messages converted to `CapturedQuestion`)
- `LegacyReadingSession` → (Not directly migrated, data preserved in book progress)
- `LegacyUsageTracking` → (Not directly migrated)

## Migration Process

1. **Check for Old Data**: The service first checks if any legacy books exist
2. **Create Schema Containers**: Creates separate containers for old and new schemas
3. **Migrate Books**: Each legacy book is converted to a BookModel
4. **Migrate Related Data**: Quotes, notes, and AI sessions are migrated with their relationships preserved
5. **Handle Orphaned Data**: Items without associated books are linked to an "Unknown Book" placeholder
6. **Verify Migration**: Counts are compared to ensure data integrity

## Integration
The migration is automatically triggered by `SwiftDataMigrationService` which is called via the `.runSwiftDataMigrations()` view modifier in the app's main ContentView.

## Testing
To verify the migration works correctly:
1. The app should compile without errors
2. Old data should be automatically migrated on first launch
3. No data loss should occur during migration
4. All relationships should be preserved

## Notes
- The migration is designed to run only once (tracked via UserDefaults)
- A backup is created before migration starts
- Recovery mechanisms are in place if migration fails
- The old models remain defined but are only used for reading during migration