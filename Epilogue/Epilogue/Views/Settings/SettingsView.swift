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

    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false

    // Hidden developer mode activation
    @State private var developerModeUnlocked = false
    @State private var versionTapCount = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                            Label("Gradient Theme", systemImage: "paintbrush.pointed.fill")
                                .foregroundStyle(ThemeManager.shared.currentTheme.primaryAccent)
                            Spacer()
                            Text(ThemeManager.shared.currentTheme.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Appearance")
                }

                // MARK: - AI Assistant
                Section {
                    Picker("AI Provider", selection: $aiProvider) {
                        Label("Apple Intelligence", systemImage: "apple.logo")
                            .tag("apple")
                        Label {
                            HStack {
                                PerplexityLogoDetailed(size: 16)
                                Text("Perplexity")
                            }
                        } icon: {
                            EmptyView()
                        }
                        .tag("perplexity")
                    }

                    if aiProvider == "perplexity" {
                        Toggle(isOn: Binding(
                            get: { perplexityModel == "sonar-pro" },
                            set: { perplexityModel = $0 ? "sonar-pro" : "sonar" }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Use Sonar Pro")
                                    .font(.subheadline)
                                Text("More advanced reasoning")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)
                    }
                } header: {
                    Text("AI Assistant")
                }

                // MARK: - Ambient Mode
                Section {
                    Toggle("Real-time Questions", isOn: $realTimeQuestions)
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)

                    Toggle("Audio Responses", isOn: $audioFeedback)
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)

                    Picker("Default Capture", selection: $defaultCaptureType) {
                        Label("Quote", systemImage: "quote.opening")
                            .tag("quote")
                        Label("Note", systemImage: "note.text")
                            .tag("note")
                        Label("Question", systemImage: "questionmark.circle")
                            .tag("question")
                    }

                    Toggle("Show Live Transcription", isOn: $showLiveTranscriptionBubble)
                        .tint(ThemeManager.shared.currentTheme.primaryAccent)
                } header: {
                    Text("Ambient Mode")
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
                    } header: {
                        Text("Developer Options")
                    } footer: {
                        Text("Gandalf mode disables all API quotas for testing. Use responsibly!")
                    }
                }

                // MARK: - Data
                Section {
                    Button {
                        exportData()
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Data")
                }

                // MARK: - About
                Section {
                    // Hidden gesture: Tap version 7 times to unlock developer mode
                    HStack {
                        Text("Version")
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
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://readepilogue.com/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        CreditsView()
                    } label: {
                        Text("Credits")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your books, notes, and reading data. This action cannot be undone.")
            }
            .alert("Export Complete", isPresented: $showingExportSuccess) {
                Button("OK") { }
            } message: {
                Text("Your data has been exported successfully.")
            }
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
            // Delete all books
            let bookDescriptor = FetchDescriptor<BookModel>()
            let books = try? modelContext.fetch(bookDescriptor)
            books?.forEach { modelContext.delete($0) }

            // Delete all notes
            let noteDescriptor = FetchDescriptor<CapturedNote>()
            let notes = try? modelContext.fetch(noteDescriptor)
            notes?.forEach { modelContext.delete($0) }

            // Delete all quotes
            let quoteDescriptor = FetchDescriptor<CapturedQuote>()
            let quotes = try? modelContext.fetch(quoteDescriptor)
            quotes?.forEach { modelContext.delete($0) }

            // Save context
            try? modelContext.save()

            // Reset settings
            UserDefaults.standard.removeObject(forKey: "defaultCaptureType")
            UserDefaults.standard.removeObject(forKey: "aiProvider")
            UserDefaults.standard.removeObject(forKey: "perplexityModel")
            UserDefaults.standard.removeObject(forKey: "gandalfMode")

            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - Supporting Views
// Removed SyncStatusView and DetailedSyncStatusSheet - already defined in SyncStatusManager.swift
// CreditsView is now in its own file with beautiful video and glass effects