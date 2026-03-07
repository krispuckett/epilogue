# Migration Safety Test Plan

## Scenario: User with V2 data upgrades to V3

### Pre-Migration State (V2)
- User has 50 books in library
- 20 notes, 15 quotes, 10 reading sessions
- All data stored in CloudKit with V2 schema

### Migration Process (V2 → V3)
1. App launches with V3 code
2. SwiftData detects schema version mismatch
3. Runs `EpilogueMigrationPlan.migrateV2toV3`
4. **Custom migration preserves all existing data**
5. Adds `coverImageData: Data?` to BookModel (nil by default)
6. Migration completes

### Post-Migration State (V3)
- ✅ All 50 books still present with original data
- ✅ All 20 notes preserved
- ✅ All 15 quotes preserved
- ✅ All 10 reading sessions preserved
- ✅ New field `coverImageData` exists (all nil initially)
- ✅ Background service will populate covers over time

## What Changed
- **Structure**: Added optional field
- **User Data**: NOTHING (all preserved)
- **User Experience**: Seamless upgrade

## Testing Steps Before TestFlight

1. **Create Test Database with V2 Schema**
   - Checkout git commit BEFORE coverImageData was added
   - Run app, add 10 test books
   - Add notes, quotes, sessions
   - Close app

2. **Upgrade to V3 Schema**
   - Checkout latest code (with coverImageData)
   - Run app again
   - **Verify all 10 books are still there**
   - **Verify all notes/quotes/sessions intact**
   - Check console for migration success logs

3. **Verify New Features Work**
   - Add new book → should cache cover
   - Go offline → ambient mode queues questions
   - Check status pill shows correct state

## Why This is Safe

**SwiftData Migration Rules:**
- ✅ Adding optional fields = SAFE (lightweight migration)
- ✅ Adding fields with defaults = SAFE
- ❌ Removing fields = DANGEROUS (needs custom migration)
- ❌ Changing field types = DANGEROUS (needs custom migration)
- ❌ Renaming fields = DANGEROUS (needs custom migration)

**Our Change:**
```swift
@Attribute(.externalStorage) var coverImageData: Data?
```
- Optional (`Data?`) - existing records get `nil`
- External storage - large data stored separately
- Zero impact on existing fields

## Emergency Rollback Plan (if needed)

If somehow migration fails in production:

1. **Quick Fix**: Revert to V2 schema
   ```swift
   let schema = Schema(versionedSchema: EpilogueSchemaV2.self)
   ```

2. **User Impact**: None - V2 and V3 are forward compatible

3. **TestFlight Hotfix**:
   - Remove `coverImageData` field
   - Remove V3 schema
   - Push update within hours

## Confidence Level: 95%

**Why Not 100%?**
- First time adding this specific field
- CloudKit sync behavior during migration unknown

**Recommendation:**
- Test migration path manually first
- Start with small TestFlight group (10-20 users)
- Monitor crash reports for 24h
- Expand to full TestFlight if clean
- Release to App Store

**Signs Migration is Working:**
- Console logs show: "✅ V3 Migration complete"
- Book count matches pre-migration
- No data loss reports from beta testers
- Cover caching starts working in background