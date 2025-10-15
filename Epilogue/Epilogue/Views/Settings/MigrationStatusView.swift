import SwiftUI
import SwiftData

struct MigrationStatusView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var migrationStats: MigrationStats?
    @State private var isLoading = true
    @State private var bookCount = 0
    @State private var noteCount = 0
    @State private var quoteCount = 0
    @State private var questionCount = 0
    
    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                                .tint(DesignSystem.Colors.primaryAccent)
                            Text("Checking migration status...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    // Migration Status
                    Section("Migration Status") {
                        HStack {
                            Label("Status", systemImage: migrationCompleted ? "checkmark.circle.fill" : "clock.fill")
                                .foregroundColor(migrationCompleted ? .green : .orange)
                            Spacer()
                            Text(migrationCompleted ? "Completed" : "Pending")
                                .foregroundColor(.secondary)
                        }
                        
                        if let stats = migrationStats {
                            HStack {
                                Label("Migration Date", systemImage: "calendar")
                                Spacer()
                                Text(stats.timestamp, style: .date)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Current Data
                    Section("Current Library") {
                        DataRow(label: "Books", count: bookCount, icon: "book.fill", color: .blue)
                        DataRow(label: "Notes", count: noteCount, icon: "note.text", color: .purple)
                        DataRow(label: "Quotes", count: quoteCount, icon: "quote.bubble.fill", color: .green)
                        DataRow(label: "Questions", count: questionCount, icon: "questionmark.circle.fill", color: .orange)
                    }
                    
                    // Migration Details
                    if let stats = migrationStats {
                        Section("Migration Details") {
                            if stats.totalBooks > 0 {
                                MigrationDetailRow(
                                    label: "Books Migrated",
                                    success: stats.migratedBooks,
                                    failed: stats.failedBooks,
                                    total: stats.totalBooks
                                )
                            }
                            
                            if stats.migratedQuotes > 0 || stats.failedQuotes > 0 {
                                MigrationDetailRow(
                                    label: "Quotes Migrated",
                                    success: stats.migratedQuotes,
                                    failed: stats.failedQuotes,
                                    total: stats.migratedQuotes + stats.failedQuotes
                                )
                            }
                            
                            if stats.migratedNotes > 0 || stats.failedNotes > 0 {
                                MigrationDetailRow(
                                    label: "Notes Migrated",
                                    success: stats.migratedNotes,
                                    failed: stats.failedNotes,
                                    total: stats.migratedNotes + stats.failedNotes
                                )
                            }
                            
                            if stats.migratedAISessions > 0 || stats.failedAISessions > 0 {
                                MigrationDetailRow(
                                    label: "AI Sessions Migrated",
                                    success: stats.migratedAISessions,
                                    failed: stats.failedAISessions,
                                    total: stats.migratedAISessions + stats.failedAISessions
                                )
                            }
                        }
                    }
                    
                    // Information
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("About Migration", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundColor(DesignSystem.Colors.primaryAccent)
                            
                            Text("Data migration ensures your books, notes, quotes, and sessions are transferred from the old app structure to the new one.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            if !migrationCompleted {
                                Text("Migration will run automatically when you next launch the app.")
                                    .font(.footnote)
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Data Migration")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadMigrationStatus()
        }
    }
    
    private var migrationCompleted: Bool {
        UserDefaults.standard.bool(forKey: "com.epilogue.dataMigrationCompleted.v2")
    }
    
    private func loadMigrationStatus() async {
        // Load migration stats from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "com.epilogue.migrationStats"),
           let stats = try? JSONDecoder().decode(MigrationStats.self, from: data) {
            self.migrationStats = stats
        }
        
        // Count current data
        do {
            bookCount = try modelContext.fetchCount(FetchDescriptor<BookModel>())
            noteCount = try modelContext.fetchCount(FetchDescriptor<CapturedNote>())
            quoteCount = try modelContext.fetchCount(FetchDescriptor<CapturedQuote>())
            questionCount = try modelContext.fetchCount(FetchDescriptor<CapturedQuestion>())
        } catch {
            #if DEBUG
            print("Failed to count data: \(error)")
            #endif
        }
        
        isLoading = false
    }
}

// MARK: - Components

private struct DataRow: View {
    let label: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(color)
            Spacer()
            Text("\(count)")
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
    }
}

private struct MigrationDetailRow: View {
    let label: String
    let success: Int
    let failed: Int
    let total: Int
    
    private var successRate: Double {
        guard total > 0 else { return 1.0 }
        return Double(success) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                if failed > 0 {
                    Text("\(success)/\(total)")
                        .foregroundColor(.orange)
                } else {
                    Text("\(success)")
                        .foregroundColor(.green)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(failed > 0 ? Color.orange : Color.green)
                        .frame(width: geometry.size.width * successRate, height: 8)
                }
            }
            .frame(height: 8)
            
            if failed > 0 {
                Text("\(failed) failed")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

// Migration Stats Model (matches the one in DataMigrationService)
private struct MigrationStats: Codable {
    var totalBooks = 0
    var migratedBooks = 0
    var failedBooks = 0
    var migratedQuotes = 0
    var failedQuotes = 0
    var migratedNotes = 0
    var failedNotes = 0
    var migratedAISessions = 0
    var failedAISessions = 0
    var timestamp = Date()
}