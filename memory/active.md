# Active Context

## Current Focus
KRI-42 @Observable migration: Wave 1 (10 core) + Wave 2 (27 services) done. 37 total migrated, 61 remaining.

## Recent Changes
- KRI-42 Wave 2 (uncommitted): 27 more classes migrated to @Observable
  - Singleton services: SimplifiedStoreKitManager, AppStateManager, CommandHistoryManager, PerformanceMonitor, MicroInteractionManager, OfflineQueueManager, PerplexityQuotaManager, GoogleBooksService, EnhancedTrendingBooksService, CognitivePatternRecognizer, QuoteIntelligence
  - View-local viewmodels (by agents): SonarChatViewModel, OptimizedAIQueryViewModel, PerplexityChatViewModel, UsageStatsViewModel, AnalyticsDashboardViewModel, LiveQuoteCaptureViewModel, LiveTextCaptureViewModel, DataScannerCoordinator, UltraFastScannerCoordinator, ScannerCoordinator, ParticleSystem, BookCameraManager, UndoManager, BatchSelectionManager, InteractiveBookManager, TextEditorCursorTracker
  - MicroInteractionManager: @AppStorage -> manual UserDefaults (incompatible with @Observable)
  - GoogleBooksService: eliminated LAST @EnvironmentObject in codebase
  - Fixed objectWillChange.send() in SettingsView (PerplexityQuotaManager)
  - Fixed Combine assign(to: &$prop) in OptimizedAIQueryView -> .sink pattern
  - Zero @EnvironmentObject remaining anywhere
  - Build verified clean
- KRI-42 Wave 1 (commit b3b7384): 10 core services migrated
- Bug bash (commit c505016): KRI-71,72,38,39,70,36,37,85,46,75
- KRI-35 (commit 729dd9a): Write-through cache
- KRI-47: Canceled, KRI-40: Closed, KRI-77: Closed

## Known Issues
- 61 remaining ObservableObject classes (Voice/AI/Ambient infrastructure, lower priority)
- Wave 2 changes not yet committed
- Pre-existing uncommitted changes in EnhancedGoogleBooksService.swift, CLAUDE.md
- KRI-35 gap: LibraryViewModel mutation methods still only write UserDefaults

## Next Steps
- Commit Wave 2 changes
- KRI-42 Wave 3: Remaining 61 ObservableObject classes (mostly Voice/AI/Ambient subsystems)
- Continue P1 backlog (KRI-45 cache filteredBooks, KRI-48 AI silence, KRI-49 ResponseCache)
- Test app thoroughly after @Observable migration
