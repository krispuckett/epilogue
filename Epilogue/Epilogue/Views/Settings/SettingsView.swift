import SwiftUI
import SwiftData

// Import models and utilities
import Foundation

struct SettingsView: View {
    @AppStorage("gradientIntensity") private var gradientIntensity: Double = 1.0
    @AppStorage("enableAnimations") private var enableAnimations = true
    @AppStorage("defaultCaptureType") private var defaultCaptureType = "quote"
    @AppStorage("voiceQuality") private var voiceQuality = "high"
    @AppStorage("showLiveTranscriptionBubble") private var showLiveTranscriptionBubble = true
    @AppStorage("aiProvider") private var aiProvider = "apple"
    @AppStorage("perplexityModel") private var perplexityModel = "sonar"
    @AppStorage("enableAnalytics") private var enableAnalytics = false
    @AppStorage("enableDataSync") private var enableDataSync = false
    @AppStorage("processOnDevice") private var processOnDevice = true
    @AppStorage("gandalfMode") private var gandalfMode = false
    
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSuccess = false
    @State private var showingAPIKeySheet = false
    @State private var apiKey = ""
    @State private var hasStoredAPIKey = false
    @State private var showingSyncStatus = false
    
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
                
                // MARK: - Sync & Backup
                Section {
                    Button {
                        showingSyncStatus = true
                    } label: {
                        HStack {
                            Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            SyncStatusView()
                        }
                    }
                    
                    Toggle("Enable Auto-Sync", isOn: $enableDataSync)
                    
                } header: {
                    Text("Sync & Backup")
                } footer: {
                    Text("Sync your data across devices when connected to the internet.")
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
                        // API key is now built-in - no configuration needed
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
                            .tint(DesignSystem.Colors.primaryAccent)
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
                
                // MARK: - Developer Options (Gandalf Mode)
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
                        PerplexityService.shared.enableGandalf(enabled)
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
                            .tint(DesignSystem.Colors.primaryAccent)
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
                    
                    Toggle("Show Live Transcription", isOn: $showLiveTranscriptionBubble)
                        .tint(.orange)
                } header: {
                    Text("Reading Preferences")
                }
                
                // MARK: - Ambient Mode Settings
                Section {
                    Toggle(isOn: .init(
                        get: { 
                            // Default to true for real-time questions
                            UserDefaults.standard.object(forKey: "realTimeQuestions") as? Bool ?? true
                        },
                        set: { UserDefaults.standard.set($0, forKey: "realTimeQuestions") }
                    )) {
                        Label("Real-time Questions", systemImage: "questionmark.bubble")
                    }
                    .tint(.orange)
                    
                    Toggle(isOn: .init(
                        get: { UserDefaults.standard.bool(forKey: "audioFeedback") },
                        set: { UserDefaults.standard.set($0, forKey: "audioFeedback") }
                    )) {
                        Label("Audio Responses", systemImage: "speaker.wave.2")
                    }
                    .tint(.orange)
                    
                    HStack {
                        Label("Processing", systemImage: "cpu")
                        Spacer()
                        Text(UserDefaults.standard.bool(forKey: "realTimeQuestions") ? "Immediate" : "Post-Session")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    if UserDefaults.standard.bool(forKey: "audioFeedback") {
                        HStack {
                            Label("Voice", systemImage: "person.wave.2")
                            Spacer()
                            Text("System Default")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Ambient Mode")
                } footer: {
                    Text("Real-time questions process immediately with AI responses. Audio feedback speaks responses aloud.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            // API key sheet removed - API key is now built-in
            .sheet(isPresented: $showingSyncStatus) {
                DetailedSyncStatusSheet(isPresented: $showingSyncStatus)
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
                id: note.id?.uuidString ?? UUID().uuidString,
                content: note.content ?? "",
                timestamp: note.timestamp ?? Date(),
                pageNumber: note.pageNumber,
                bookTitle: note.book?.title
            )
        }
        
        let exportQuotes = quotes.map { quote in
            ExportQuote(
                id: quote.id?.uuidString ?? UUID().uuidString,
                text: quote.text ?? "",
                author: quote.author,
                timestamp: quote.timestamp ?? Date(),
                pageNumber: quote.pageNumber,
                bookTitle: quote.book?.title,
                notes: quote.notes
            )
        }
        
        let exportQuestions = questions.map { question in
            ExportQuestion(
                id: question.id?.uuidString ?? UUID().uuidString,
                content: question.content ?? "",
                timestamp: question.timestamp ?? Date(),
                pageNumber: question.pageNumber,
                bookTitle: question.book?.title,
                isAnswered: question.isAnswered ?? false,
                answer: question.answer
            )
        }
        
        // Export user settings from UserDefaults
        _ = UserDefaults.standard
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
        // Important: Delete in correct order to respect relationships
        do {
            // First delete parent entities that have relationships
            try modelContext.delete(model: AmbientSession.self)
            try modelContext.delete(model: QueuedQuestion.self)
            
            // Then delete related entities
            try modelContext.delete(model: CapturedQuestion.self)
            try modelContext.delete(model: CapturedNote.self)
            try modelContext.delete(model: CapturedQuote.self)
            
            // Finally delete books
            try modelContext.delete(model: BookModel.self)
            
            // Save changes
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
    @State private var appeared = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero Section with App Icon
                VStack(spacing: 20) {
                    // Animated App Icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.45, blue: 0.16),
                                        Color(red: 0.95, green: 0.35, blue: 0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.16).opacity(0.5), radius: 20)
                            .scaleEffect(appeared ? 1.0 : 0.8)
                            .opacity(appeared ? 1.0 : 0)
                        
                        Image(systemName: "book.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(appeared ? 0 : -10))
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)
                    
                    VStack(spacing: 8) {
                        Text("Epilogue")
                            .font(.system(size: 48, weight: .bold, design: .serif))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("A thoughtful reading companion")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .kerning(0.5)
                        
                        Text("Version 1.0")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 4)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Creator Section
                VStack(spacing: 24) {
                    Text("CREATED BY")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(2)
                    
                    VStack(spacing: 16) {
                        // Profile image placeholder with gradient
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.3, green: 0.5, blue: 0.9),
                                            Color(red: 0.5, green: 0.3, blue: 0.9)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Text("KP")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .blue.opacity(0.3), radius: 15)
                        
                        VStack(spacing: 4) {
                            Text("Kris Puckett")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("iOS Developer & Book Enthusiast")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                
                // Technologies Section
                VStack(spacing: 20) {
                    Text("POWERED BY")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(2)
                    
                    VStack(spacing: 12) {
                        TechCard(
                            icon: "swift",
                            title: "SwiftUI & iOS 26",
                            description: "Built with the latest technologies",
                            color: .orange
                        )
                        
                        TechCard(
                            icon: "mic.fill",
                            title: "WhisperKit",
                            description: "On-device voice transcription",
                            color: .blue
                        )
                        
                        TechCard(
                            icon: "brain",
                            title: "Perplexity AI",
                            description: "Intelligent reading companion",
                            color: .purple
                        )
                        
                        TechCard(
                            icon: "icloud.fill",
                            title: "CloudKit",
                            description: "Seamless sync across devices",
                            color: .cyan
                        )
                    }
                }
                .padding(.horizontal)
                
                // Special Thanks
                VStack(spacing: 16) {
                    Text("SPECIAL THANKS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .kerning(2)
                    
                    Text("To all the beta testers, early adopters, and book lovers who helped shape Epilogue into what it is today.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Text("Made with ❤️ for readers everywhere")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)
                }
                .padding(.vertical, 32)
            }
            .padding(.bottom, 40)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.118))
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }
}

// Tech Card Component
struct TechCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [BookModel.self, CapturedNote.self, CapturedQuote.self, CapturedQuestion.self])
}
