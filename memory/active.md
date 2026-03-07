# Active Context

## Current Focus
Post-1.4 polish and new features. Large batch of uncommitted work in progress including social sharing, companion system, return cards, and various UI improvements across library, notes, sessions, and settings views.

## Recent Changes
- Replaced AsyncImage with SharedBookCoverView for offline caching (5b602fe)
- Fixed recommendation engine and generic session improvements (142ffae)
- Auto-enrich books on app startup after CloudKit sync (0d1e7a2)
- Custom cover upload and search performance improvements (4b6901f)
- Knowledge graph system for thematic connections (c54e579)

## Open Questions
- Large number of uncommitted changes across many views — need to review and commit incrementally
- Multiple new untracked files (SocialSharing/, Companion/, ReturnCard, etc.) not yet committed
- Many markdown documentation files staged for deletion (cleanup in progress)

## Next Steps
- Review and commit the pending changes in logical groups
- Test new features (social sharing, companion, return cards) on device
- Continue iOS 26 Liquid Glass polish pass
