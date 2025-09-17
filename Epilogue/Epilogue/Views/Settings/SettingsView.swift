import SwiftUI
import AVKit
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
                        // Gandalf mode is now handled in OptimizedPerplexityService
                        print("🧙‍♂️ Gandalf mode \(enabled ? "enabled" : "disabled")")
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
                            .tint(ThemeManager.shared.currentTheme.primaryAccent)
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
                }
                
                // MARK: - AI Settings
                Section {
                    Toggle(isOn: .init(
                        get: { UserDefaults.standard.bool(forKey: "useOnDeviceAI") },
                        set: { UserDefaults.standard.set($0, forKey: "useOnDeviceAI") }
                    )) {
                        Label("Use On-Device AI", systemImage: "cpu")
                    }
                    .tint(.orange)
                    
                    Text("When enabled, simple questions about your notes and highlights will be answered locally for free.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("AI Settings")
                } footer: {
                    Text("Book knowledge questions always use Perplexity for accuracy.")
                        .font(.caption)
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
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            // Video Background with Gradient Overlay
            VideoBackgroundView()

            // Gradient overlay from transparent to subtle amber
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.3),
                    .init(color: DesignSystem.Colors.primaryAccent.opacity(0.1), location: 0.6),
                    .init(color: DesignSystem.Colors.primaryAccent.opacity(0.2), location: 0.8),
                    .init(color: DesignSystem.Colors.primaryAccent.opacity(0.3), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                Spacer()

                // App Logo with liquid glass
                VStack(spacing: 24) {
                    ZStack {
                        // Glowing background
                        Circle()
                            .fill(DesignSystem.Colors.primaryAccent.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .blur(radius: 40)
                            .scaleEffect(appeared ? 1.2 : 0.8)

                        // Glass icon container
                        Image(systemName: "book.fill")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        DesignSystem.Colors.primaryAccent,
                                        DesignSystem.Colors.primaryAccent.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .glassEffect(in: .circle)
                            .shadow(color: DesignSystem.Colors.primaryAccent.opacity(0.3), radius: 20, y: 10)
                            .scaleEffect(appeared ? 1.0 : 0.8)
                            .opacity(appeared ? 1.0 : 0)
                    }
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: appeared)

                    VStack(spacing: 12) {
                        Text("Epilogue")
                            .font(.system(size: 52, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)

                        Text("A thoughtful reading companion")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .kerning(0.5)
                    }
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.3), value: appeared)
                }

                Spacer()
                Spacer()
                
                // Credits with liquid glass
                VStack(spacing: 20) {
                    Text("Version 1.0")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .kerning(1)

                    HStack {
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 40, height: 1)

                        Text("by")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .kerning(1)

                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 40, height: 1)
                    }

                    Text("Kris Puckett")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .kerning(0.5)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 48)
                .glassEffect(in: .rect(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.2),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(appeared ? 1.0 : 0)
                .offset(y: appeared ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.5), value: appeared)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Empty to keep navigation clean
            }
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
    }
}

// MARK: - Video Background View

struct VideoBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        // Get video URL - first try Bundle, then Downloads folder
        var videoURL: URL?

        // Try app bundle first
        if let bundleURL = Bundle.main.url(forResource: "readEpilogue", withExtension: "mp4") {
            videoURL = bundleURL
        } else {
            // Fallback to Downloads folder for development
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            videoURL = downloadsURL?.appendingPathComponent("readEpilogue.mp4")
        }

        guard let url = videoURL else {
            print("⚠️ Video file not found")
            // Return a gradient fallback
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.black.cgColor,
                UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1).cgColor
            ]
            gradientLayer.frame = UIScreen.main.bounds
            view.layer.addSublayer(gradientLayer)
            return view
        }

        // Create video player
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)

        // Configure player layer
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(playerLayer)

        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        // Start playing
        player.play()
        player.isMuted = true // Mute for background video

        // Add a subtle dark overlay to ensure text readability
        let overlayView = UIView(frame: UIScreen.main.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.addSubview(overlayView)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Update frame if needed
        if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.frame = uiView.bounds
        }
    }
}

// Tech Card Component (keeping for potential future use)
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
