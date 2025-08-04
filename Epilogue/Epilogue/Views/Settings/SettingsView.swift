import SwiftUI
import SwiftData

// Import models and utilities
import Foundation

struct SettingsView: View {
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("defaultCaptureType") private var defaultCaptureType = "quote"
    @AppStorage("voiceQuality") private var voiceQuality = "high"
    @AppStorage("aiProvider") private var aiProvider = "apple"
    @AppStorage("perplexityModel") private var perplexityModel = "sonar"
    @AppStorage("enableAnalytics") private var enableAnalytics = false
    @AppStorage("enableDataSync") private var enableDataSync = false
    @AppStorage("processOnDevice") private var processOnDevice = true
    
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingAPIKeySheet = false
    @State private var apiKey = ""
    @State private var hasStoredAPIKey = false
    
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
                // MARK: - Account Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Guest User")
                                .font(.headline)
                            Text("Sign in coming soon")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Sign In") {
                            // Future auth implementation
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Account")
                }
                
                // MARK: - AI & Intelligence
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
                        Button {
                            showingAPIKeySheet = true
                        } label: {
                            HStack {
                                Label("API Key", systemImage: "key.fill")
                                Spacer()
                                Text(hasStoredAPIKey ? "••••••••" : "Not Set")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Model", systemImage: "cpu")
                                Spacer()
                                Text(perplexityModel == "sonar-pro" ? "Sonar Pro" : "Sonar")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Toggle(isOn: Binding(
                                get: { perplexityModel == "sonar-pro" },
                                set: { perplexityModel = $0 ? "sonar-pro" : "sonar" }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use Sonar Pro")
                                        .font(.subheadline)
                                    Text("More advanced reasoning, slower responses")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
                        }
                    }
                    
                    Toggle(isOn: $processOnDevice) {
                        Label("Process On-Device", systemImage: "iphone")
                    }
                } header: {
                    Text("AI & Intelligence")
                } footer: {
                    Text("On-device processing keeps your data private but may be slower")
                }
                
                // MARK: - Reading Preferences
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Gradient Intensity", systemImage: "slider.horizontal.3")
                            Spacer()
                            Text("\(Int(gradientIntensity * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        
                        Slider(value: $gradientIntensity, in: 0...1)
                            .tint(Color(red: 1.0, green: 0.55, blue: 0.26))
                    }
                    
                    Toggle(isOn: $enableAnimations) {
                        Label("Enable Animations", systemImage: "sparkles")
                    }
                    
                    Picker("Default Capture", selection: $defaultCaptureType) {
                        Label("Quote", systemImage: "quote.opening")
                            .tag("quote")
                        Label("Note", systemImage: "note.text")
                            .tag("note")
                        Label("Question", systemImage: "questionmark.circle")
                            .tag("question")
                    }
                    
                    Picker("Voice Quality", selection: $voiceQuality) {
                        Text("Low").tag("low")
                        Text("Medium").tag("medium")
                        Text("High").tag("high")
                    }
                } header: {
                    Text("Reading Preferences")
                }
                
                // MARK: - Privacy & Data
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
                    
                    Toggle(isOn: $enableAnalytics) {
                        Label("Share Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    
                    Toggle(isOn: $enableDataSync) {
                        Label("Data Sync", systemImage: "icloud")
                    }
                    .disabled(true)
                } header: {
                    Text("Privacy & Data")
                } footer: {
                    Text("Data sync will be available in a future update")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://epilogue.app/privacy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://epilogue.app/terms")!) {
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
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeyEntrySheet(apiKey: $apiKey, hasStoredAPIKey: $hasStoredAPIKey)
            }
        }
        .onAppear {
            // Check if we have a stored API key
            hasStoredAPIKey = KeychainManager.shared.hasPerplexityAPIKey
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
                // Could add error handling UI here
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
            let questions: [ExportQuestion]
            let userSettings: [String: String]
        }
        
        struct ExportBook: Codable {
            let id: String
            let title: String
            let author: String
            let publishedYear: String?
            let currentPage: Int
            let readingStatus: String
            let userRating: Int?
            let userNotes: String?
            let dateAdded: Date
        }
        
        struct ExportNote: Codable {
            let id: String
            let content: String
            let timestamp: Date
            let pageNumber: Int?
            let bookTitle: String?
        }
        
        struct ExportQuote: Codable {
            let id: String
            let text: String
            let author: String?
            let timestamp: Date
            let pageNumber: Int?
            let bookTitle: String?
            let notes: String?
        }
        
        struct ExportQuestion: Codable {
            let id: String
            let content: String
            let timestamp: Date
            let pageNumber: Int?
            let bookTitle: String?
            let isAnswered: Bool
            let answer: String?
        }
        
        // Fetch all data from SwiftData
        let bookDescriptor = FetchDescriptor<BookModel>()
        let noteDescriptor = FetchDescriptor<CapturedNote>()
        let quoteDescriptor = FetchDescriptor<CapturedQuote>()
        let questionDescriptor = FetchDescriptor<CapturedQuestion>()
        
        let books = try modelContext.fetch(bookDescriptor)
        let notes = try modelContext.fetch(noteDescriptor)
        let quotes = try modelContext.fetch(quoteDescriptor)
        let questions = try modelContext.fetch(questionDescriptor)
        
        // Convert to export format
        let exportBooks = books.map { book in
            ExportBook(
                id: book.id,
                title: book.title,
                author: book.author,
                publishedYear: book.publishedYear,
                currentPage: book.currentPage,
                readingStatus: book.readingStatus,
                userRating: book.userRating,
                userNotes: book.userNotes,
                dateAdded: book.dateAdded
            )
        }
        
        let exportNotes = notes.map { note in
            ExportNote(
                id: note.id.uuidString,
                content: note.content,
                timestamp: note.timestamp,
                pageNumber: note.pageNumber,
                bookTitle: note.book?.title
            )
        }
        
        let exportQuotes = quotes.map { quote in
            ExportQuote(
                id: quote.id.uuidString,
                text: quote.text,
                author: quote.author,
                timestamp: quote.timestamp,
                pageNumber: quote.pageNumber,
                bookTitle: quote.book?.title,
                notes: quote.notes
            )
        }
        
        let exportQuestions = questions.map { question in
            ExportQuestion(
                id: question.id.uuidString,
                content: question.content,
                timestamp: question.timestamp,
                pageNumber: question.pageNumber,
                bookTitle: question.book?.title,
                isAnswered: question.isAnswered,
                answer: question.answer
            )
        }
        
        // Export user settings from UserDefaults
        let userDefaults = UserDefaults.standard
        var settings: [String: String] = [:]
        settings["gradientIntensity"] = "\(gradientIntensity)"
        settings["enableAnimations"] = "\(enableAnimations)"
        settings["defaultCaptureType"] = defaultCaptureType
        settings["voiceQuality"] = voiceQuality
        settings["aiProvider"] = aiProvider
        settings["enableAnalytics"] = "\(enableAnalytics)"
        settings["processOnDevice"] = "\(processOnDevice)"
        
        let exportData = ExportData(
            exportDate: Date(),
            appVersion: appVersion,
            books: exportBooks,
            notes: exportNotes,
            quotes: exportQuotes,
            questions: exportQuestions,
            userSettings: settings
        )
        
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = .prettyPrinted
        
        return try jsonEncoder.encode(exportData)
    }
    
    private func deleteAllData() {
        // Delete all data from SwiftData
        do {
            try modelContext.delete(model: BookModel.self)
            try modelContext.delete(model: CapturedNote.self)
            try modelContext.delete(model: CapturedQuote.self)
            try modelContext.delete(model: CapturedQuestion.self)
            try modelContext.save()
            
            // Clear caches (if available)
            // SharedBookCoverManager.shared.clearAllCaches()
            
            // Clear UserDefaults
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
        } catch {
            print("Failed to delete all data: \(error)")
        }
    }
}

// MARK: - API Key Entry Sheet

struct APIKeyEntrySheet: View {
    @Binding var apiKey: String
    @Binding var hasStoredAPIKey: Bool
    @State private var tempKey = ""
    @State private var errorMessage = ""
    @State private var showingError = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Key", text: $tempKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Perplexity API Key")
                } footer: {
                    Text("Your API key is stored securely in the keychain")
                }
            }
            .navigationTitle("API Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveAPIKey()
                        dismiss()
                    }
                    .disabled(tempKey.isEmpty)
                }
            }
        }
        .onAppear {
            // Load existing API key if available
            if let existingKey = KeychainManager.shared.getPerplexityAPIKey() {
                tempKey = existingKey
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func saveAPIKey() {
        do {
            if tempKey.isEmpty {
                // Delete the key if empty
                try KeychainManager.shared.deletePerplexityAPIKey()
                hasStoredAPIKey = false
            } else {
                // Save the key
                try KeychainManager.shared.savePerplexityAPIKey(tempKey)
                hasStoredAPIKey = true
            }
            apiKey = tempKey
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Credits View

struct CreditsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Epilogue")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("A thoughtful reading companion")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical)
            }
            
            Section("Created By") {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundStyle(.gray)
                    VStack(alignment: .leading) {
                        Text("Your Name")
                            .font(.headline)
                        Text("Developer")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Open Source Libraries") {
                Link("SwiftUI", destination: URL(string: "https://developer.apple.com/xcode/swiftui/")!)
                Link("WhisperKit", destination: URL(string: "https://github.com/argmaxinc/whisperkit")!)
            }
            
            Section("Special Thanks") {
                Text("To all beta testers and contributors")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [BookModel.self, CapturedNote.self, CapturedQuote.self, CapturedQuestion.self])
}