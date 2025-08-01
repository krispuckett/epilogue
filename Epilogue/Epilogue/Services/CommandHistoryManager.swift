import Foundation
import SwiftUI
import Combine

// MARK: - Recent Command Model

struct RecentCommand: Identifiable, Codable {
    var id = UUID()
    let text: String
    let intentType: String
    let timestamp: Date
    var count: Int
    
    var icon: String {
        switch intentType {
        case "note":
            return "note.text"
        case "quote":
            return "quote.bubble"
        case "book":
            return "book.fill"
        case "search":
            return "magnifyingglass"
        default:
            return "command"
        }
    }
    
    var iconColor: Color {
        switch intentType {
        case "note":
            return .blue
        case "quote":
            return Color.warmAmber
        case "book":
            return .green
        case "search":
            return .purple
        default:
            return .gray
        }
    }
    
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Command History Manager

@MainActor
class CommandHistoryManager: ObservableObject {
    static let shared = CommandHistoryManager()
    
    @Published var recentCommands: [RecentCommand] = []
    
    private let maxRecentCommands = 5
    private let deduplicationWindow: TimeInterval = 86400 // 24 hours
    private let userDefaultsKey = "com.epilogue.commandHistory"
    
    init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    func addCommand(_ text: String, intent: CommandIntent) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let intentType = mapIntentToType(intent)
        
        // Check for duplicate within deduplication window
        if let existingIndex = recentCommands.firstIndex(where: { command in
            command.text.lowercased() == trimmedText.lowercased() &&
            Date().timeIntervalSince(command.timestamp) < deduplicationWindow
        }) {
            // Increment count and update timestamp
            recentCommands[existingIndex].count += 1
            recentCommands[existingIndex] = RecentCommand(
                text: recentCommands[existingIndex].text,
                intentType: recentCommands[existingIndex].intentType,
                timestamp: Date(),
                count: recentCommands[existingIndex].count
            )
        } else {
            // Add new command
            let newCommand = RecentCommand(
                text: trimmedText,
                intentType: intentType,
                timestamp: Date(),
                count: 1
            )
            recentCommands.insert(newCommand, at: 0)
        }
        
        // Limit to max recent commands
        if recentCommands.count > maxRecentCommands {
            recentCommands = Array(recentCommands.prefix(maxRecentCommands))
        }
        
        // Sort by timestamp (most recent first)
        recentCommands.sort { $0.timestamp > $1.timestamp }
        
        saveHistory()
    }
    
    func clearHistory() {
        recentCommands.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    func getRecentCommands() -> [RecentCommand] {
        return recentCommands
    }
    
    // MARK: - Private Methods
    
    private func mapIntentToType(_ intent: CommandIntent) -> String {
        switch intent {
        case .createNote:
            return "note"
        case .createQuote:
            return "quote"
        case .addBook, .existingBook:
            return "book"
        case .searchLibrary, .searchNotes, .searchAll:
            return "search"
        default:
            return "unknown"
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([RecentCommand].self, from: data) else {
            return
        }
        
        // Filter out commands older than 7 days
        let weekAgo = Date().addingTimeInterval(-604800)
        recentCommands = decoded.filter { $0.timestamp > weekAgo }
        
        // Sort by timestamp
        recentCommands.sort { $0.timestamp > $1.timestamp }
        
        // Limit to max
        if recentCommands.count > maxRecentCommands {
            recentCommands = Array(recentCommands.prefix(maxRecentCommands))
        }
    }
    
    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(recentCommands) else { return }
        UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
    }
}