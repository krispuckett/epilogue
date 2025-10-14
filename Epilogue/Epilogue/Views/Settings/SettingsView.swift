import SwiftUI
import AVKit
import SwiftData

// Import models and utilities
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

    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingCacheClearedToast = false
    @State private var toastMessage = ""

    // Batch enrichment state
    @State private var isEnriching = false
    @State private var enrichmentProgress: (current: Int, total: Int, title: String)?

    // Hidden developer mode activation
    @State private var developerModeUnlocked = false
    @State private var versionTapCount = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var libraryViewModel: LibraryViewModel

    // Get app version
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            Form {
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
                } header: {
                    Text(L10n.Settings.Section.appearance)
                }

                // MARK: - Library Management
                Section {
                    NavigationLink {
                        CleanGoodreadsImportView()
                            .environmentObject(libraryViewModel)
                    } label: {
                        Label(L10n.Settings.importFromGoodreads, systemImage: "books.vertical.fill")
                            .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                    }
                    .accessibilityLabel("Import from Goodreads")
                    .accessibilityHint("Double tap to import your books from Goodreads")
                    .accessibilityIdentifier("settings.goodreadsImport")
                } header: {
                    Text(L10n.Settings.Section.library)
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

                        // Enrich button
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
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Data & Enrichment")
                } footer: {
                    Text("AI-generated summaries provide spoiler-free context, themes, and character info for your books. New books are enriched automatically in the background.")
                }

                // MARK: - AI Assistant
                Section {
                    HStack {
                        Label {
                            Text(L10n.Settings.aiProvider)
                        } icon: {
                            // Use the new SVG-accurate logo
                            PerplexityLogoSVG(size: 20)
                                .drawingGroup()  // Flatten view hierarchy
                        }
                        Spacer()
                        Text("settings.ai_provider.perplexity".localized())
                            .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: Binding(
                        get: { perplexityModel == "sonar-pro" },
                        set: { perplexityModel = $0 ? "sonar-pro" : "sonar" }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Settings.useSonarPro)
                                .font(.subheadline)
                            Text(L10n.Settings.sonarProDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(ThemeManager.shared.currentTheme.primaryAccent)
                    .accessibilityLabel("Use Sonar Pro model for more advanced reasoning")
                    .accessibilityIdentifier("settings.useSonarPro")
                } header: {
                    Text(L10n.Settings.Section.aiAssistant)
                }

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
                            print("🧙‍♂️ Gandalf mode \(enabled ? "enabled" : "disabled")")
                            if enabled {
                                // Haptic feedback for activation
                                SensoryFeedback.success()
                            }
                        }

                        if gandalfMode {
                            Label("Testing mode active - quotas disabled", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Button {
                            Task { @MainActor in
                                // Safety check before migration
                                let safetyCheck = CloudKitSafetyCheck.shared
                                let summary = await safetyCheck.getMigrationSummary(for: modelContext.container)
                                print("📋 Migration Safety Check:\n\(summary)")

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
                            WidgetDesignLab()
                        } label: {
                            Label("Widget Design Lab", systemImage: "rectangle.3.group.fill")
                                .foregroundStyle(.orange)
                        }

                        NavigationLink {
                            AmbientOrbExporter()
                        } label: {
                            Label("Export Ambient Orb", systemImage: "circle.hexagongrid.fill")
                                .foregroundStyle(.orange)
                        }

                        NavigationLink {
                            PremiumPaywallView()
                        } label: {
                            Label("Preview Premium Paywall", systemImage: "crown.fill")
                                .foregroundStyle(.yellow)
                        }

                        Toggle(isOn: Binding(
                            get: { UserDefaults.standard.bool(forKey: "devShowConversationCounter") },
                            set: { UserDefaults.standard.set($0, forKey: "devShowConversationCounter") }
                        )) {
                            Label("Show Conversation Counter", systemImage: "circle.dotted.circle")
                                .foregroundStyle(.cyan)
                        }

                        Button {
                            SimplifiedStoreKitManager.shared.resetMonthlyCount()
                            SensoryFeedback.light()
                        } label: {
                            Label("Reset Conversation Count", systemImage: "arrow.counterclockwise")
                                .foregroundStyle(.green)
                        }
                    } header: {
                        Text("Developer Options")
                    } footer: {
                        Text("Gandalf mode disables all API quotas for testing. Use responsibly!\n\nReset CloudKit Migration will re-run the sync process for all local data.")
                    }
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
                            .foregroundStyle(.orange)
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

                    Link(destination: URL(string: "https://readepilogue.com/privacy")!) {
                        HStack {
                            Text(L10n.Settings.privacyPolicy)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://readepilogue.com/terms")!) {
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
                        NotificationCenter.default.post(name: Notification.Name("ShowOnboarding"), object: nil)

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
            }
            .navigationTitle(L10n.Settings.title)
            .navigationBarTitleDisplayMode(.large)
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
        }
    }

    // MARK: - Hidden Gesture Handler
    private func handleVersionTap() {
        versionTapCount += 1

        // Reset counter after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if versionTapCount < 7 {
                versionTapCount = 0
            }
        }

        // Unlock developer mode after 7 taps
        if versionTapCount == 7 {
            developerModeUnlocked = true
            versionTapCount = 0

            // Special effects for unlocking
            SensoryFeedback.impact(.heavy)

            // Optional: Show a subtle toast or message
            print("🧙‍♂️ You shall pass! Developer mode unlocked.")
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
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
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
                print("Export failed: \(error)")
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
            let userRating: Int?
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

                print("✅ All data deleted successfully")

                await MainActor.run {
                    // Show success feedback
                    SensoryFeedback.success()

                    // Dismiss after a brief delay to let user see the action completed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                print("❌ Error deleting data: \(error)")
                await MainActor.run {
                    SensoryFeedback.error()
                }
            }
        }
    }

    private func enrichAllBooks() {
        guard !isEnriching else { return }

        print("🎨 [SETTINGS] Starting batch enrichment...")
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
                print("✅ [SETTINGS] Batch enrichment complete")
            }
        }
    }
}

// MARK: - Supporting Views
// Removed SyncStatusView and DetailedSyncStatusSheet - already defined in SyncStatusManager.swift
// CreditsView is now in its own file with beautiful video and glass effects