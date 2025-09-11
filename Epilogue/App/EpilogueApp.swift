import SwiftUI
import SwiftData

@main
struct EpilogueApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            // Configure for iCloud backup
            let schema = Schema([
                Book.self,
                Quote.self,
                Note.self,
                AISession.self,
                AIMessage.self,
                UsageTracking.self,
                ReadingSession.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .automatic // Enables automatic iCloud backup
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: ModelMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .modelContainer(modelContainer)
                .onAppear {
                    configureAppearance()
                }
        }
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showingExport = false
    @State private var showingSettings = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BookListView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)
            
            UnifiedSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(1)
            
            UsageStatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
                .tag(2)
            
            SettingsView(
                showingExport: $showingExport,
                showingSettings: $showingSettings
            )
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .sheet(isPresented: $showingExport) {
            ExportDataView()
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            RefinedOnboardingView {
                hasCompletedOnboarding = true
                showOnboarding = false
            }
        }
    }
}

struct SettingsView: View {
    @Binding var showingExport: Bool
    @Binding var showingSettings: Bool
    @AppStorage("enableAutoBackup") private var enableAutoBackup = true
    @AppStorage("enableAnalytics") private var enableAnalytics = false
    @AppStorage("defaultExportFormat") private var defaultExportFormat = "json"
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Data Management") {
                    Button(action: { showingExport = true }) {
                        Label("Export Library", systemImage: "square.and.arrow.up")
                    }
                    
                    Toggle("Automatic iCloud Backup", isOn: $enableAutoBackup)
                    
                    Text("Your data is automatically backed up to iCloud when enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Privacy") {
                    Toggle("Analytics", isOn: $enableAnalytics)
                    
                    Text("No personal data is collected. Analytics help improve the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Export Settings") {
                    Picker("Default Format", selection: $defaultExportFormat) {
                        Text("JSON").tag("json")
                        Text("Markdown").tag("markdown")
                        Text("CSV").tag("csv")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
                    
                    Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct UsageStatsView: View {
    @Query private var usageTracking: [UsageTracking]
    @Query private var books: [Book]
    @Query private var quotes: [Quote]
    @Query private var notes: [Note]
    
    var todaysUsage: UsageTracking? {
        usageTracking.first { Calendar.current.isDateInToday($0.date) }
    }
    
    var totalQuotes: Int {
        quotes.count
    }
    
    var totalNotes: Int {
        notes.count
    }
    
    var favoriteQuotes: Int {
        quotes.filter { $0.isFavorite }.count
    }
    
    var pinnedNotes: Int {
        notes.filter { $0.isPinned }.count
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Library Overview
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Library Overview")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Books",
                                value: "\(books.count)",
                                icon: "books.vertical",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "Quotes",
                                value: "\(totalQuotes)",
                                icon: "quote.bubble",
                                color: .green
                            )
                            
                            StatCard(
                                title: "Notes",
                                value: "\(totalNotes)",
                                icon: "note.text",
                                color: .orange
                            )
                        }
                    }
                    .padding()
                    
                    // Highlights
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Highlights")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            StatCard(
                                title: "Favorites",
                                value: "\(favoriteQuotes)",
                                icon: "star.fill",
                                color: .yellow
                            )
                            
                            StatCard(
                                title: "Pinned",
                                value: "\(pinnedNotes)",
                                icon: "pin.fill",
                                color: .red
                            )
                        }
                    }
                    .padding()
                    
                    // API Usage (if available)
                    if let usage = todaysUsage {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Today's API Usage")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("API Calls")
                                    Spacer()
                                    Text("\(usage.apiCallCount)")
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Text("Quota Remaining")
                                    Spacer()
                                    Text("\(usage.quotaRemaining) / \(usage.quotaLimit)")
                                        .fontWeight(.semibold)
                                }
                                
                                ProgressView(value: usage.quotaPercentageUsed)
                                    .tint(usage.isQuotaExceeded ? .red : .blue)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding()
                    }
                    
                    // Reading Progress
                    if !books.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Currently Reading")
                                .font(.headline)
                            
                            ForEach(books.filter { $0.readingProgress > 0 && $0.readingProgress < 1 }.prefix(3)) { book in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(book.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text(book.author)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(book.progressPercentage)%")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                
                                ProgressView(value: book.readingProgress)
                                    .tint(.blue)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    EpilogueApp().body
}