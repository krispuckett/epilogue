import SwiftUI
import Combine
import AVKit
import SwiftData
import Foundation

struct SettingsView: View {
    // Essential settings only for TestFlight
    @AppStorage("defaultCaptureType") private var defaultCaptureType = "quote"
    @AppStorage("showLiveTranscriptionBubble") private var showLiveTranscriptionBubble = true
    @AppStorage("aiProvider") private var aiProvider = "apple"
    @AppStorage("perplexityModel") private var perplexityModel = "sonar"
    @AppStorage("gandalfMode") private var gandalfMode = false
    @AppStorage("realTimeQuestions") private var realTimeQuestions = true
    @AppStorage("audioFeedback") private var audioFeedback = false
    @AppStorage("alwaysShowInput") private var alwaysShowInput = false
    @AppStorage("socialFeaturesEnabled") private var socialFeaturesEnabled = false
    @AppStorage("atmosphereEngineV2") private var atmosphereEngineV2 = true
    @AppStorage("feature.gradient.harmony_layers") private var harmonyLayersEnabled = true
    @AppStorage("feature.gradient.accent_bloom") private var accentBloomEnabled = true
    @AppStorage("feature.gradient.cover_texture_fallback") private var coverTextureEnabled = false
    @AppStorage("feature.gradient.ambient_breathing") private var ambientBreathingEnabled = false
    @AppStorage("feature.gradient.unified_extractor") private var unifiedExtractorEnabled = true
    @AppStorage("feature.gradient.saliency_extraction") private var saliencyEnabled = true
    @AppStorage("feature.gradient.confidence_scoring") private var confidenceScoringEnabled = true
    @AppStorage("feature.gradient.legibility_layers") private var legibilityLayersEnabled = false
    @AppStorage("feature.gradient.debug_overlay") private var debugOverlayEnabled = false
    @AppStorage("fluidGradientExperiment") private var fluidGradientExperiment = false
    @AppStorage("enableAnimatedBackgrounds") private var enableAnimatedBackgrounds = true

    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingCacheClearedToast = false
    @State private var toastMessage = ""
    @State private var showingWhatsNew = false

    // Privacy & Data state
    @State private var showingClearTranscriptsConfirmation = false
    @State private var showingClearAIHistoryConfirmation = false
    @State private var autoDeleteTranscripts = UserDefaults.standard.bool(forKey: "privacy_autoDeleteTranscripts")
    @State private var transcriptRetention = DataRetentionService.RetentionPeriod(rawValue: UserDefaults.standard.string(forKey: "privacy_transcriptRetention") ?? "90_days") ?? .ninetyDays
    @State private var autoDeleteAIHistory = UserDefaults.standard.bool(forKey: "privacy_autoDeleteAIHistory")
    @State private var aiHistoryRetention = DataRetentionService.RetentionPeriod(rawValue: UserDefaults.standard.string(forKey: "privacy_aiHistoryRetention") ?? "90_days") ?? .ninetyDays
    @State private var dataSummary: DataRetentionService.DataSummary?

    // Batch enrichment state
    @State private var isEnriching = false
    @State private var enrichmentProgress: (current: Int, total: Int, title: String)?

    // New Features Lab state
    @State private var showingDailyReview = false
    @State private var showingBookDNAStats = false

    // Hidden developer mode activation
    @State private var developerModeUnlocked = false
    @State private var versionTapCount = 0
    @State private var versionTapTimer: Timer?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LibraryViewModel.self) var libraryViewModel

    // Get app version
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Atmospheric gradient background
                AmbientChatGradientView()
                    .opacity(0.4)
                    .ignoresSafeArea(.all)

                Color.black.opacity(0.15)
                    .ignoresSafeArea(.all)

            Form {
                // MARK: - Epilogue+ Upsell Card
                if !SimplifiedStoreKitManager.shared.isPlus {
                    Section {
                        EpiloguePlusUpsellCard()
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                // MARK: - Appearance
                Section {
                    NavigationLink {
                        ThemeSelectionView()
                    } label: {
                        HStack {
                            Label(L10n.Settings.gradientTheme, systemImage: "paintbrush.pointed.fill")
                                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                            Spacer()
                            Text(ThemeManager.shared.currentTheme.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Gradient theme, currently \(ThemeManager.shared.currentTheme.displayName)")
                    .accessibilityHint("Double tap to change gradient theme")
                    .accessibilityIdentifier("settings.gradientTheme")

                    Toggle(isOn: $enableAnimatedBackgrounds) {
                        Label("Animated Backgrounds", systemImage: "waveform.path")
                            .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                    }
                    .tint(ThemeManager.shared.currentTheme.primaryAccent)
                    .accessibilityLabel("Animated Backgrounds")
                    .accessibilityHint("When off, book backgrounds use static gradients")
                    .accessibilityIdentifier("settings.animatedBackgrounds")
                } header: {
                    Text(L10n.Settings.Section.appearance)
                }

                // MARK: - Library Management
                Section {
                    NavigationLink {
                        CleanGoodreadsImportView()
                            .environment(libraryViewModel)
                    } label: {
                        Label(L10n.Settings.importFromGoodreads, systemImage: "books.vertical.fill")
                            .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                    }
                    .accessibilityLabel("Import from Goodreads")
                    .accessibilityHint("Double tap to import your books from Goodreads")
                    .accessibilityIdentifier("settings.goodreadsImport")
                    
                    FeatureFlagView(.readwiseIntegration) {
                        NavigationLink {
                            ReadwiseSyncView()
                        } label: {
                            HStack {
                                Label("Sync with Readwise", systemImage: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                                
                                Spacer()
                                
                                if ReadwiseService.shared.isAuthenticated {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .accessibilityLabel("Sync with Readwise")
                        .accessibilityHint("Double tap to sync your highlights with Readwise")
                        .accessibilityIdentifier("settings.readwiseSync")
                    }
                } header: {
                    Text(L10n.Settings.Section.library)
                }

                // MARK: - Bookstore Preference
                Section {
                    NavigationLink {
                        BookstorePreferenceView()
                    } label: {
                        HStack {
                            Label("Preferred Bookstore", systemImage: "cart")
                                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                            Spacer()
                            Text(BookstoreURLBuilder.shared.preferredBookstore.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Preferred bookstore, currently \(BookstoreURLBuilder.shared.preferredBookstore.rawValue)")
                    .accessibilityHint("Double tap to change where book links open")
                    .accessibilityIdentifier("settings.bookstore")
                } header: {
                    Text("Shopping")
                } footer: {
                    Text("Choose where \"Buy\" links take you when viewing book recommendations.")
                }

                // MARK: - Data & Enrichment
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        // Enrichment stats
                        let stats = BatchEnrichmentService.shared.getEnrichmentStats(modelContext: modelContext)

                        HStack {
                            Label("AI Book Summaries", systemImage: "sparkles.rectangle.stack")
                                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                            Spacer()
                            if stats.total > 0 {
                                Text("\(stats.enriched)/\(stats.total)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if stats.pending > 0 {
                            Text("\(stats.pending) book\(stats.pending == 1 ? "" : "s") need AI-generated summaries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if stats.total > 0 {
                            Text("All books have AI-generated summaries")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        // Progress indicator
                        if let progress = enrichmentProgress {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enriching: \(progress.title)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                ProgressView(value: Double(progress.current), total: Double(progress.total))
                                    .tint(ThemeManager.shared.currentTheme.primaryAccent)

                                Text("\(progress.current) of \(progress.total)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 4)
                        }

                        // Enrich button (only shows if there are pending books)
                        if stats.pending > 0 {
                            Button {
                                enrichAllBooks()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isEnriching {
                                        ProgressView()
                                            .tint(ThemeManager.shared.currentTheme.primaryAccent)
                                        Text("Enriching...")
                                    } else {
                                        Image(systemName: "wand.and.stars")
                                        Text("Enrich All Books")
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .disabled(isEnriching)
                            .buttonStyle(.borderedProminent)
                            .tint(ThemeManager.shared.currentTheme.primaryAccent)
                            .padding(.top, 8)
                        }

                        // Re-enrich button (always available if there are books)
                        if stats.total > 0 {
                            Button {
                                reEnrichAllBooks()
                            } label: {
                                HStack {
                                    Spacer()
                                    if isEnriching {
                                        ProgressView()
                                            .tint(.orange)
                                        Text("Re-enriching...")
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Re-enrich All Books")
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .disabled(isEnriching)
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Data & Enrichment")
                } footer: {
                    Text("AI-generated summaries provide spoiler-free context, themes, and character info for your books. Use \"Re-enrich\" to refresh data if book info seems incorrect.")
                }

                // MARK: - Privacy & Data
                privacyAndDataSection

                // MARK: - Data Summary
                dataSummarySection

                // MARK: - Ambient Mode
                Section {
                    Toggle(L10n.Settings.realtimeQuestions, isOn: $realTimeQuestions)
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)
                        .id("realtime")  // Stable identity
                        .accessibilityLabel("Real-time questions")
                        .accessibilityIdentifier("settings.realtimeQuestions")

                    Toggle(L10n.Settings.audioResponses, isOn: $audioFeedback)
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)
                        .id("audio")  // Stable identity
                        .accessibilityLabel("Audio responses")
                        .accessibilityIdentifier("settings.audioResponses")

                    Picker(L10n.Settings.defaultCapture, selection: $defaultCaptureType) {
                        Label("settings.capture.quote".localized(), systemImage: "quote.opening")
                            .tag("quote")
                        Label("settings.capture.note".localized(), systemImage: "note.text")
                            .tag("note")
                        Label("settings.capture.question".localized(), systemImage: "questionmark.circle")
                            .tag("question")
                    }

                    Toggle(L10n.Settings.showLiveTranscription, isOn: $showLiveTranscriptionBubble)
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)
                        .id("transcription")  // Stable identity
                        .accessibilityLabel("Show live transcription")
                        .accessibilityIdentifier("settings.showLiveTranscription")

                    Toggle(L10n.Settings.alwaysShowInput, isOn: $alwaysShowInput)
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)
                        .id("alwaysShowInput")  // Stable identity
                        .accessibilityLabel("Always show input")
                        .accessibilityIdentifier("settings.alwaysShowInput")
                } header: {
                    Text(L10n.Settings.Section.ambientMode)
                }

                // MARK: - Developer Options (Hidden unless unlocked)
                if developerModeUnlocked || gandalfMode {
                    Section {
                        Toggle(isOn: $gandalfMode) {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading) {
                                    Text("Gandalf Mode")
                                        .foregroundColor(.purple)
                                    Text("Unlimited testing (no quota limits)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onChange(of: gandalfMode) { _, enabled in
                            #if DEBUG
                            print("🧙‍♂️ Gandalf mode \(enabled ? "enabled" : "disabled")")
                            #endif
                            if enabled {
                                // Haptic feedback for activation
                                SensoryFeedback.success()
                                // Reset quota sheet state to prevent showing old quota exceeded sheets
                                PerplexityQuotaManager.shared.showQuotaExceededSheet = false
                            }
                        }

                        if gandalfMode {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("🧙‍♂️ UNLIMITED MODE ACTIVE", systemImage: "infinity")
                                    .font(.caption.bold())
                                    .foregroundColor(.purple)
                                Label("Quotas disabled - ask as many questions as you want", systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }

                        BlurRevealToggle()

                        Toggle(isOn: $socialFeaturesEnabled) {
                            HStack {
                                Image(systemName: "figure.2")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Social Features")
                                        .foregroundColor(.orange)
                                    Text("Share, Read Together, Companions")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .tint(.orange)

                    } header: {
                        Text("Developer")
                    }

                    // MARK: - Gradient Lab
                    Section {
                        Toggle(isOn: $atmosphereEngineV2) {
                            HStack {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundColor(.cyan)
                                VStack(alignment: .leading) {
                                    Text("Atmosphere Engine v2")
                                        .foregroundColor(.cyan)
                                    Text("Unified OKLCH gradient pipeline")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .tint(.cyan)
                        .onChange(of: atmosphereEngineV2) { _, enabled in
                            #if DEBUG
                            print("🎨 Atmosphere Engine v2 \(enabled ? "enabled" : "disabled")")
                            #endif
                            if enabled {
                                SensoryFeedback.success()
                                Task {
                                    AtmosphereEngine.shared.clearAll()
                                }
                            }
                        }

                        if atmosphereEngineV2 {
                            gradientLabToggles
                        }

                        fluidGradientToggle

                    } header: {
                        Label("Gradient Lab", systemImage: "paintpalette")
                    }

                    Section {
                        Button {
                            Task { @MainActor in
                                // Safety check before migration
                                let safetyCheck = CloudKitSafetyCheck.shared
                                let summary = await safetyCheck.getMigrationSummary(for: modelContext.container)
                                #if DEBUG
                                print("📋 Migration Safety Check:\n\(summary)")
                                #endif

                                // Backup data before migration
                                await safetyCheck.backupCriticalData(from: modelContext.container)

                                // Proceed with migration
                                CloudKitMigrationService.shared.resetMigration()
                                await CloudKitMigrationService.shared.checkAndPerformMigration(container: modelContext.container)
                            }
                        } label: {
                            Label("Reset CloudKit Migration", systemImage: "arrow.clockwise.icloud")
                                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                        }

                        NavigationLink {
                            PremiumPaywallView()
                        } label: {
                            Label("Preview Premium Paywall", systemImage: "crown.fill")
                                .foregroundStyle(.yellow)
                        }

                        Button {
                            showingWhatsNew = true
                            SensoryFeedback.light()
                        } label: {
                            Label("Preview What's New", systemImage: "star.circle")
                                .foregroundStyle(.cyan)
                        }

                        NavigationLink {
                            ShaderLabView()
                        } label: {
                            Label("Shader Lab", systemImage: "cube.transparent")
                                .foregroundStyle(.cyan)
                        }

                        orbLabLink

                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: .showReturnCard, object: nil)
                            }
                        } label: {
                            Label("Preview Welcome Back", systemImage: "hand.wave.fill")
                                .foregroundStyle(.mint)
                        }

                    } header: {
                        Text("Developer Options")
                    } footer: {
                        Text("Gandalf mode disables all API quotas for testing. Use responsibly!\n\nReset CloudKit Migration will re-run the sync process for all local data.")
                    }

                    // MARK: - New Features Lab
                    newFeaturesLabSection
                }

                // MARK: - iCloud Sync
                CloudKitStatusView()
                
                // MARK: - Data
                Section {
                    Button {
                        exportData()
                    } label: {
                        Label(L10n.Settings.exportAllData, systemImage: "square.and.arrow.up")
                            .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                    }
                    .accessibilityLabel("Export all data")
                    .accessibilityHint("Double tap to export your books, notes, and settings")
                    .accessibilityIdentifier("settings.exportData")

                    Button {
                        Task { @MainActor in
                            // Clear all caches
                            SharedBookCoverManager.shared.clearAllCaches()
                            DisplayedImageStore.clearAllCaches()
                            await BookColorPaletteCache.shared.clearCache()

                            // Show confirmation toast
                            toastMessage = "toast.image_caches_cleared".localized()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showingCacheClearedToast = true
                            }

                            // Hide toast after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation {
                                    showingCacheClearedToast = false
                                }
                            }
                        }
                    } label: {
                        Label(L10n.Settings.clearImageCaches, systemImage: "trash")
                            .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label(L10n.Settings.deleteAllData, systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .accessibilityLabel("Delete all data")
                    .accessibilityIdentifier("settings.deleteAllData")
                } header: {
                    Text(L10n.Settings.Section.data)
                } footer: {
                    Text("settings.clear_caches_footer".localized())
                }

                // MARK: - About
                Section {
                    // Hidden gesture: Tap version 7 times to unlock developer mode
                    HStack {
                        Text(L10n.Settings.version)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleVersionTap()
                    }

                    Link(destination: URL(string: "https://krispuckett.craft.me/BcGmXbnrNCvSGp")!) {
                        HStack {
                            Text(L10n.Settings.privacyPolicy)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://krispuckett.craft.me/clvC7VnuiypGo1")!) {
                        HStack {
                            Text(L10n.Settings.termsOfService)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        CreditsView()
                    } label: {
                        Text(L10n.Settings.credits)
                    }

                    Button {
                        // Replay onboarding
                        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")

                        // Post notification to trigger onboarding
                        NotificationCenter.default.post(name: .showOnboarding, object: nil)

                        dismiss()
                    } label: {
                        HStack {
                            Text(L10n.Settings.replayOnboarding)
                            Spacer()
                            Image(systemName: "play.circle")
                                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                        }
                    }
                    .accessibilityLabel("Replay onboarding")
                    .accessibilityHint("Double tap to view the app introduction again")
                    .accessibilityIdentifier("settings.replayOnboarding")
                } header: {
                    Text(L10n.Settings.Section.about)
                }

                // MARK: - Developer Mode (Hidden, unlocked by tapping version 7 times)
                if developerModeUnlocked {
                    Section {
                        NavigationLink {
                            AmbientPresenceStatesExperiment()
                        } label: {
                            HStack {
                                Label("Ambient Presence States", systemImage: "waveform.circle.fill")
                                    .foregroundStyle(Color(red: 1.0, green: 0.549, blue: 0.259))
                                Spacer()
                                Text("Experiment")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Ambient Presence States Experiment")
                        .accessibilityHint("Developer tool for tuning ambient orb behavior")

                    } header: {
                        Text("🧙‍♂️ Developer Mode")
                    } footer: {
                        Text("Experimental features and developer tools. Tap version 7 times to lock.")
                            .onTapGesture(count: 7) {
                                developerModeUnlocked = false
                                SensoryFeedback.impact(.medium)
                            }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .onAppear {
                // Style list row backgrounds with glass effect
                UITableView.appearance().backgroundColor = .clear
                UITableViewCell.appearance().backgroundColor = UIColor(white: 1, alpha: 0.05)

                // Load privacy data summary
                dataSummary = DataRetentionService.shared.getDataSummary(modelContext: modelContext)
            }
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.done) {
                        dismiss()
                    }
                }
            }
            .alert("alert.delete_data.title".localized(), isPresented: $showingDeleteConfirmation) {
                Button(L10n.Action.cancel, role: .cancel) { }
                Button(L10n.Action.delete, role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("alert.delete_data.message".localized())
            }
            .alert("alert.export_complete.title".localized(), isPresented: $showingExportSuccess) {
                Button(L10n.General.ok) { }
            } message: {
                Text("alert.export_complete.message".localized())
            }
            .modifier(GlassToastModifier(isShowing: $showingCacheClearedToast, message: toastMessage))
            .sheet(isPresented: $showingWhatsNew) {
                WhatsNewView()
            }
            .fullScreenCover(isPresented: $showingDailyReview) {
                DailyReviewView()
            }
            .sheet(isPresented: $showingBookDNAStats) {
                BookDNAStatsView()
            }
            .alert("Clear Voice Transcripts", isPresented: $showingClearTranscriptsConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    let count = DataRetentionService.shared.clearAllVoiceTranscripts(modelContext: modelContext)
                    toastMessage = "Cleared \(count) ambient session\(count == 1 ? "" : "s")"
                    dataSummary = DataRetentionService.shared.getDataSummary(modelContext: modelContext)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingCacheClearedToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showingCacheClearedToast = false }
                    }
                }
            } message: {
                Text("This will permanently delete all ambient reading session transcripts. Notes and quotes captured during those sessions will not be deleted.")
            }
            .alert("Clear AI History", isPresented: $showingClearAIHistoryConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    let count = DataRetentionService.shared.clearAllAIHistory(modelContext: modelContext)
                    toastMessage = "Cleared \(count) AI conversation\(count == 1 ? "" : "s")"
                    dataSummary = DataRetentionService.shared.getDataSummary(modelContext: modelContext)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingCacheClearedToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showingCacheClearedToast = false }
                    }
                }
            } message: {
                Text("This will permanently delete all AI conversation history and memory threads. The AI will no longer remember previous conversations.")
            }
        }
    }

    // MARK: - Privacy & Data Section
    @ViewBuilder
    private var privacyAndDataSection: some View {
        Section {
            Toggle(isOn: $autoDeleteTranscripts) {
                Label("Auto-delete Ambient Transcripts", systemImage: "mic.slash")
                    .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
            }
            .tint(ThemeManager.shared.currentTheme.primaryAccent)
            .onChange(of: autoDeleteTranscripts) { _, newValue in
                DataRetentionService.shared.autoDeleteTranscripts = newValue
            }

            if autoDeleteTranscripts {
                Picker("Transcript Retention", selection: $transcriptRetention) {
                    ForEach(DataRetentionService.RetentionPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .onChange(of: transcriptRetention) { _, newValue in
                    DataRetentionService.shared.transcriptRetentionPeriod = newValue
                }
            }

            Toggle(isOn: $autoDeleteAIHistory) {
                Label("Auto-delete AI History", systemImage: "brain")
                    .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
            }
            .tint(ThemeManager.shared.currentTheme.primaryAccent)
            .onChange(of: autoDeleteAIHistory) { _, newValue in
                DataRetentionService.shared.autoDeleteAIHistory = newValue
            }

            if autoDeleteAIHistory {
                Picker("AI History Retention", selection: $aiHistoryRetention) {
                    ForEach(DataRetentionService.RetentionPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .onChange(of: aiHistoryRetention) { _, newValue in
                    DataRetentionService.shared.aiHistoryRetentionPeriod = newValue
                }
            }

            Button(role: .destructive) {
                showingClearTranscriptsConfirmation = true
            } label: {
                Label("Clear All Voice Transcripts", systemImage: "waveform.slash")
                    .foregroundStyle(.red)
            }

            Button(role: .destructive) {
                showingClearAIHistoryConfirmation = true
            } label: {
                Label("Clear All AI History", systemImage: "xmark.bin")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Privacy & Data")
        } footer: {
            Text("Control how long sensitive data is retained. Auto-delete removes data older than the selected period on each app launch.")
        }
    }

    // MARK: - Data Summary Section
    @ViewBuilder
    private var dataSummarySection: some View {
        if let summary = dataSummary {
            Section {
                HStack {
                    Label("Ambient Sessions", systemImage: "mic.fill")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(summary.ambientSessionCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Notes & Quotes", systemImage: "note.text")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(summary.notesAndQuotesCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("AI Conversations", systemImage: "brain")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(summary.aiConversationCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Last Mic Access", systemImage: "clock")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let lastAccess = summary.lastMicrophoneAccess {
                        Text(lastAccess, style: .relative)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Never")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Data Summary")
            }
        }
    }

    // MARK: - New Features Lab Section
    @ViewBuilder
    private var newFeaturesLabSection: some View {
        Section {
            // Memory Resurfacing toggle
            Toggle(isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "memoryResurfacingEnabled") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "memoryResurfacingEnabled")
                    SensoryFeedback.light()
                    if newValue {
                        let ctx = ModelContext(modelContext.container)
                        MemoryResurfacingService.shared.configure(with: modelContext.container)
                        MemoryResurfacingService.shared.generateCardsFromExistingContent(modelContext: ctx)
                    }
                }
            )) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.pink)
                    VStack(alignment: .leading) {
                        Text("Memory Resurfacing")
                            .foregroundColor(.pink)
                        Text("Spaced repetition daily review for quotes & notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tint(.pink)

            if UserDefaults.standard.bool(forKey: "memoryResurfacingEnabled") {
                Button {
                    showingDailyReview = true
                    SensoryFeedback.light()
                } label: {
                    Label("Open Daily Review", systemImage: "rectangle.stack.fill")
                        .foregroundStyle(.pink)
                }
            }

            Button {
                showingBookDNAStats = true
                SensoryFeedback.light()
            } label: {
                Label("Book DNA Profiles", systemImage: "leaf.fill")
                    .foregroundStyle(.green)
            }

            Button {
                Task { @MainActor in
                    CoverAcquisitionService.shared.configure(with: modelContext.container)
                    await CoverAcquisitionService.shared.fetchMissingCovers(container: modelContext.container)
                    toastMessage = "Cover pipeline scan complete"
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showingCacheClearedToast = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { showingCacheClearedToast = false }
                    }
                }
            } label: {
                Label("Run Cover Pipeline", systemImage: "photo.stack")
                    .foregroundStyle(.blue)
            }

            Button {
                ReEntryIntelligenceService.shared.clearDismissals()
                dismiss()
                SensoryFeedback.light()
            } label: {
                Label("Reset Re-entry Cards", systemImage: "arrow.uturn.backward")
                    .foregroundStyle(.orange)
            }

            Button {
                let ctx = ModelContext(modelContext.container)
                BookDNAService.shared.configure(with: modelContext.container)
                BookDNAService.shared.generateMissingDNAs(modelContext: ctx)
                SensoryFeedback.success()
                toastMessage = "Book DNA profiles generated"
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingCacheClearedToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation { showingCacheClearedToast = false }
                }
            } label: {
                Label("Generate Missing DNA", systemImage: "wand.and.stars.inverse")
                    .foregroundStyle(.green)
            }
        } header: {
            Text("New Features Lab")
        } footer: {
            Text("Memory Resurfacing adds a daily review button to the library. Book DNA powers personalized recommendations. Cover Pipeline fetches high-res covers from multiple sources.")
        }
    }

    // MARK: - Hidden Gesture Handler
    private func handleVersionTap() {
        versionTapCount += 1

        // Cancel any existing timer and start a fresh one
        versionTapTimer?.invalidate()
        versionTapTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            // Only reset if we haven't reached 7 yet
            if versionTapCount < 7 {
                versionTapCount = 0
            }
        }

        // Unlock developer mode after 7 taps
        if versionTapCount == 7 {
            versionTapTimer?.invalidate()
            versionTapTimer = nil
            developerModeUnlocked = true
            versionTapCount = 0

            // Special effects for unlocking
            SensoryFeedback.impact(.heavy)

            // Optional: Show a subtle toast or message
            #if DEBUG
            print("🧙‍♂️ You shall pass! Developer mode unlocked.")
            #endif
        } else if versionTapCount >= 3 {
            // Give subtle feedback that something might happen
            SensoryFeedback.light()
        }
    }

    // MARK: - Data Management
    private func exportData() {
        Task {
            do {
                let exportData = try await generateExportData()
                guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    #if DEBUG
                    print("❌ Could not access documents directory")
                    #endif
                    return
                }
                let exportURL = documentsPath.appendingPathComponent("EpilogueExport-\(Date().formatted(date: .numeric, time: .omitted)).json")

                try exportData.write(to: exportURL)

                await MainActor.run {
                    // Share the exported file
                    let activityVC = UIActivityViewController(activityItems: [exportURL], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityVC, animated: true)
                    }
                    showingExportSuccess = true
                }
            } catch {
                #if DEBUG
                print("Export failed: \(error)")
                #endif
            }
        }
    }

    private func generateExportData() async throws -> Data {
        struct ExportData: Codable {
            let exportDate: Date
            let appVersion: String
            let books: [ExportBook]
            let notes: [ExportNote]
            let quotes: [ExportQuote]
            let userSettings: [String: String]
        }

        struct ExportBook: Codable {
            let id: String
            let title: String
            let author: String
            let currentPage: Int
            let readingStatus: String
            let userRating: Double?  // Supports half-star ratings
            let dateAdded: Date
        }

        struct ExportNote: Codable {
            let id: String
            let content: String
            let timestamp: Date
            let bookTitle: String?
        }

        struct ExportQuote: Codable {
            let id: String
            let text: String
            let timestamp: Date
            let bookTitle: String?
        }

        // Fetch data from SwiftData
        let descriptor = FetchDescriptor<BookModel>()
        let books = try modelContext.fetch(descriptor)

        let noteDescriptor = FetchDescriptor<CapturedNote>()
        let notes = try modelContext.fetch(noteDescriptor)

        let quoteDescriptor = FetchDescriptor<CapturedQuote>()
        let quotes = try modelContext.fetch(quoteDescriptor)

        // Build export data
        let exportData = ExportData(
            exportDate: Date(),
            appVersion: "\(appVersion) (\(buildNumber))",
            books: books.map { book in
                ExportBook(
                    id: book.localId,
                    title: book.title,
                    author: book.author,
                    currentPage: book.currentPage,
                    readingStatus: book.readingStatus,
                    userRating: book.userRating,
                    dateAdded: book.dateAdded
                )
            },
            notes: notes.map { note in
                ExportNote(
                    id: note.id?.uuidString ?? UUID().uuidString,
                    content: note.content ?? "",
                    timestamp: note.timestamp ?? Date(),
                    bookTitle: note.book?.title
                )
            },
            quotes: quotes.map { quote in
                ExportQuote(
                    id: quote.id?.uuidString ?? UUID().uuidString,
                    text: quote.text ?? "",
                    timestamp: quote.timestamp ?? Date(),
                    bookTitle: quote.book?.title
                )
            },
            userSettings: [
                "defaultCaptureType": defaultCaptureType,
                "aiProvider": aiProvider,
                "perplexityModel": perplexityModel,
                "showLiveTranscriptionBubble": String(showLiveTranscriptionBubble),
                "realTimeQuestions": String(realTimeQuestions),
                "audioFeedback": String(audioFeedback)
            ]
        )

        return try JSONEncoder().encode(exportData)
    }

    private func deleteAllData() {
        Task {
            do {
                // Delete all books (this should cascade to sessions)
                let bookDescriptor = FetchDescriptor<BookModel>()
                let books = try modelContext.fetch(bookDescriptor)
                books.forEach { modelContext.delete($0) }

                // Delete all ambient sessions
                let sessionDescriptor = FetchDescriptor<AmbientSession>()
                let sessions = try modelContext.fetch(sessionDescriptor)
                sessions.forEach { modelContext.delete($0) }

                // Delete all notes
                let noteDescriptor = FetchDescriptor<CapturedNote>()
                let notes = try modelContext.fetch(noteDescriptor)
                notes.forEach { modelContext.delete($0) }

                // Delete all quotes
                let quoteDescriptor = FetchDescriptor<CapturedQuote>()
                let quotes = try modelContext.fetch(quoteDescriptor)
                quotes.forEach { modelContext.delete($0) }

                // Delete all questions
                let questionDescriptor = FetchDescriptor<CapturedQuestion>()
                let questions = try modelContext.fetch(questionDescriptor)
                questions.forEach { modelContext.delete($0) }

                // Delete all queued questions
                let queuedDescriptor = FetchDescriptor<QueuedQuestion>()
                let queuedQuestions = try modelContext.fetch(queuedDescriptor)
                queuedQuestions.forEach { modelContext.delete($0) }

                // Save context - this is critical!
                try modelContext.save()

                // Clear only app-specific UserDefaults, not system ones
                // DON'T use removePersistentDomain as it can break SwiftData
                UserDefaults.standard.removeObject(forKey: "defaultCaptureType")
                UserDefaults.standard.removeObject(forKey: "aiProvider")
                UserDefaults.standard.removeObject(forKey: "perplexityModel")
                UserDefaults.standard.removeObject(forKey: "gandalfMode")
                UserDefaults.standard.removeObject(forKey: "realTimeQuestions")
                UserDefaults.standard.removeObject(forKey: "audioFeedback")
                UserDefaults.standard.removeObject(forKey: "showLiveTranscriptionBubble")
                UserDefaults.standard.removeObject(forKey: "gradientIntensity")
                UserDefaults.standard.removeObject(forKey: "enableAnimations")
                UserDefaults.standard.removeObject(forKey: "developerModeUnlocked")
                UserDefaults.standard.removeObject(forKey: "versionTapCount")

                // Clear Perplexity quota tracking
                UserDefaults.standard.removeObject(forKey: "perplexity_questions_used_today")
                UserDefaults.standard.removeObject(forKey: "perplexity_quota_last_reset")

                // Clean SwiftData store files for fresh start
                DataRecovery.cleanSwiftDataStore()

                // Force synchronize
                UserDefaults.standard.synchronize()

                #if DEBUG
                print("✅ All data deleted successfully")
                #endif

                await MainActor.run {
                    // Show success feedback
                    SensoryFeedback.success()

                    // Dismiss after a brief delay to let user see the action completed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                #if DEBUG
                print("❌ Error deleting data: \(error)")
                #endif
                await MainActor.run {
                    SensoryFeedback.error()
                }
            }
        }
    }

    private func enrichAllBooks() {
        guard !isEnriching else { return }

        #if DEBUG
        print("🎨 [SETTINGS] Starting batch enrichment...")
        #endif
        isEnriching = true
        enrichmentProgress = nil

        Task {
            await BatchEnrichmentService.shared.enrichAllBooks(
                modelContext: modelContext,
                progressHandler: { current, total, title in
                    enrichmentProgress = (current, total, title)
                }
            )

            await MainActor.run {
                isEnriching = false
                enrichmentProgress = nil
                toastMessage = "All books enriched!"
                showingCacheClearedToast = true
                #if DEBUG
                print("✅ [SETTINGS] Batch enrichment complete")
                #endif
            }
        }
    }

    private func reEnrichAllBooks() {
        guard !isEnriching else { return }

        #if DEBUG
        print("🔄 [SETTINGS] Starting FORCE re-enrichment...")
        #endif
        isEnriching = true
        enrichmentProgress = nil

        Task {
            await BatchEnrichmentService.shared.reEnrichAllBooks(
                modelContext: modelContext,
                progressHandler: { current, total, title in
                    enrichmentProgress = (current, total, title)
                }
            )

            await MainActor.run {
                isEnriching = false
                enrichmentProgress = nil
                toastMessage = "All books re-enriched with fresh data!"
                showingCacheClearedToast = true
                #if DEBUG
                print("✅ [SETTINGS] Force re-enrichment complete")
                #endif
            }
        }
    }
    // MARK: - Gradient Lab Toggles (extracted to help type-checker)

    private var orbLabLink: some View {
        NavigationLink {
            OrbLabView()
        } label: {
            Label("Orb Lab", systemImage: "circle.hexagongrid.fill")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var fluidGradientToggle: some View {
        Toggle(isOn: $fluidGradientExperiment) {
            HStack {
                Image(systemName: "drop.halffull")
                    .foregroundColor(.indigo)
                VStack(alignment: .leading) {
                    Text("Fluid Gradient")
                        .foregroundColor(.indigo)
                    Text("Domain-warped FBM noise experiment")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(.indigo)
    }

    @ViewBuilder
    private var gradientLabToggles: some View {
        Group {
            Toggle("Harmony Layers", isOn: $harmonyLayersEnabled)
                .foregroundColor(.secondary)
            Toggle("Accent Bloom", isOn: $accentBloomEnabled)
                .foregroundColor(.secondary)
            Toggle("Cover-as-Texture Fallback", isOn: $coverTextureEnabled)
                .foregroundColor(.secondary)
            Toggle("Ambient Breathing", isOn: $ambientBreathingEnabled)
                .foregroundColor(.secondary)
        }
        Group {
            Divider()
            Toggle("Unified Extractor", isOn: $unifiedExtractorEnabled)
                .foregroundColor(.secondary)
            Toggle("Vision Saliency", isOn: $saliencyEnabled)
                .foregroundColor(.secondary)
            Toggle("Confidence Scoring", isOn: $confidenceScoringEnabled)
                .foregroundColor(.secondary)
        }
        Group {
            Divider()
            Toggle("Legibility Layers", isOn: $legibilityLayersEnabled)
                .foregroundColor(.secondary)
            Toggle("Debug Overlay", isOn: $debugOverlayEnabled)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Views
// Removed SyncStatusView and DetailedSyncStatusSheet - already defined in SyncStatusManager.swift
// CreditsView is now in its own file with beautiful video and glass effects

// MARK: - Epilogue+ Upsell Card
struct EpiloguePlusUpsellCard: View {
    @State private var storeKit = SimplifiedStoreKitManager.shared
    @State private var themeManager = ThemeManager.shared
    @State private var showingPaywall = false

    var body: some View {
        Button {
            showingPaywall = true
        } label: {
            ZStack {
                // Gradient: ambient mode at top, black at bottom
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color.black, location: 0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Ambient gradient at top only
                VStack {
                    AmbientChatGradientView()
                        .frame(height: 120)
                        .blur(radius: 40)
                        .opacity(0.8)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Header with pricing
                    HStack(alignment: .firstTextBaseline) {
                        Text("EPILOGUE+")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .kerning(1.5)
                            .foregroundStyle(themeManager.currentTheme.primaryAccent)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("$7.99")
                                    .font(.system(size: 24, weight: .bold, design: .default))
                                    .foregroundStyle(.white)
                                Text("/mo")
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6))
                            }

                            Text("or $67/yr  save 30%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(themeManager.currentTheme.primaryAccent)
                        }
                    }

                    // Main value prop - only 2 features
                    VStack(alignment: .leading, spacing: 16) {
                        featureLine(check: true, text: "Unlimited ambient mode conversations")
                        featureLine(check: true, text: "Advanced AI models")
                    }

                    // Usage counter - creates urgency
                    HStack(spacing: 6) {
                        Text("\(storeKit.conversationsUsed)/8")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme.primaryAccent)

                        Text("free conversations used this month")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .padding(.top, 4)

                    // CTA button
                    HStack {
                        Spacer()
                        Text("Continue with Epilogue+")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .glassEffect(.regular.tint(themeManager.currentTheme.primaryAccent.opacity(0.15)), in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                themeManager.currentTheme.primaryAccent.opacity(0.3),
                                lineWidth: 1
                            )
                    }
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryAccent.opacity(0.35),
                                themeManager.currentTheme.primaryAccent.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Upgrade to Epilogue Plus. $7.99 per month or $67 per year with 30% savings")
        .accessibilityHint("Double tap to view subscription options. You've used \(storeKit.conversationsUsed) of 8 free conversations.")
        .sheet(isPresented: $showingPaywall) {
            PremiumPaywallView()
        }
    }

    private func featureLine(check: Bool, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeManager.currentTheme.primaryAccent)
                .frame(width: 16)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Blur Reveal Toggle (extracted to avoid type-checker overflow)
private struct BlurRevealToggle: View {
    @AppStorage("blurRevealNotes") private var blurRevealNotes = false

    var body: some View {
        Toggle(isOn: $blurRevealNotes) {
            HStack {
                Image(systemName: "text.below.photo")
                    .foregroundColor(.cyan)
                VStack(alignment: .leading) {
                    Text("Blur Reveal Notes")
                        .foregroundColor(.cyan)
                    Text("Smooth height + fade expand animation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .tint(.cyan)
    }
}