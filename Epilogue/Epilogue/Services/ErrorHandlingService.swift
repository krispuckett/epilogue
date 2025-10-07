import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - Error Types

enum EpilogueError: LocalizedError {
    case networkError(String)
    case dataCorruption(String)
    case audioProcessingFailed(String)
    case transcriptionFailed(String)
    case bookNotFound(String)
    case imageLoadingFailed(String)
    case aiServiceUnavailable(String)
    case storageError(String)
    case migrationFailed(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .dataCorruption(let message):
            return "Data Error: \(message)"
        case .audioProcessingFailed(let message):
            return "Audio Error: \(message)"
        case .transcriptionFailed(let message):
            return "Transcription Error: \(message)"
        case .bookNotFound(let message):
            return "Book Not Found: \(message)"
        case .imageLoadingFailed(let message):
            return "Image Loading Error: \(message)"
        case .aiServiceUnavailable(let message):
            return "AI Service Error: \(message)"
        case .storageError(let message):
            return "Storage Error: \(message)"
        case .migrationFailed(let message):
            return "Migration Error: \(message)"
        case .unknown(let message):
            return "Error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Check your internet connection and try again."
        case .dataCorruption:
            return "Try restarting the app. If the problem persists, you may need to reinstall."
        case .audioProcessingFailed:
            return "Check microphone permissions in Settings."
        case .transcriptionFailed:
            return "Try speaking more clearly or check your language settings."
        case .bookNotFound:
            return "The book may have been deleted. Try searching for it again."
        case .imageLoadingFailed:
            return "The image may be unavailable. Try refreshing."
        case .aiServiceUnavailable:
            return "Check your API key in Settings or try again later."
        case .storageError:
            return "Check available storage space on your device."
        case .migrationFailed:
            return "Try restarting the app. Your data is safe."
        case .unknown:
            return "Try restarting the app. If the problem persists, contact support."
        }
    }
}

// MARK: - Error Handling Service

@MainActor
final class ErrorHandlingService: ObservableObject {
    static let shared = ErrorHandlingService()
    
    @Published var currentError: ErrorPresentation?
    @Published var errorHistory: [ErrorRecord] = []
    
    private let logger = Logger(subsystem: "com.epilogue", category: "ErrorHandling")
    private let maxErrorHistory = 50
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Handle an error with appropriate logging and UI presentation
    func handle(_ error: Error, context: String? = nil, recoveryAction: (() -> Void)? = nil) {
        // Log the error
        logger.error("Error in \(context ?? "Unknown Context"): \(error.localizedDescription)")
        
        // Create error record
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        // Add to history
        errorHistory.insert(record, at: 0)
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeLast()
        }
        
        // Determine if we should show UI
        if shouldShowError(error) {
            currentError = ErrorPresentation(
                error: error,
                context: context,
                recoveryAction: recoveryAction
            )
        }
        
        // Send telemetry if critical
        if isCriticalError(error) {
            sendErrorTelemetry(record)
        }
    }
    
    /// Handle an error silently (log only, no UI)
    func handleSilently(_ error: Error, context: String? = nil) {
        logger.warning("Silent error in \(context ?? "Unknown Context"): \(error.localizedDescription)")
        
        let record = ErrorRecord(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        errorHistory.insert(record, at: 0)
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeLast()
        }
    }
    
    /// Clear current error presentation
    func dismissError() {
        currentError = nil
    }
    
    /// Clear error history
    func clearHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func shouldShowError(_ error: Error) -> Bool {
        // Don't show certain errors to avoid annoying users
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                // Only show if we haven't shown a network error recently
                return !hasRecentNetworkError()
            case .cancelled:
                return false // User cancelled, don't show
            default:
                return true
            }
        }
        
        // Don't show SwiftData constraint errors
        if error.localizedDescription.contains("UNIQUE constraint") {
            return false
        }
        
        return true
    }
    
    private func hasRecentNetworkError() -> Bool {
        let recentCutoff = Date().addingTimeInterval(-30) // 30 seconds
        return errorHistory.contains { record in
            record.timestamp > recentCutoff &&
            (record.error as? URLError)?.code == .notConnectedToInternet
        }
    }
    
    private func isCriticalError(_ error: Error) -> Bool {
        guard let epilogueError = error as? EpilogueError else {
            return false
        }

        switch epilogueError {
        case .dataCorruption, .migrationFailed:
            return true
        default:
            return false
        }
    }
    
    private func sendErrorTelemetry(_ record: ErrorRecord) {
        // In production, this would send to analytics service
        logger.critical("Critical error occurred: \(record.error.localizedDescription)")
    }
}

// MARK: - Supporting Types

struct ErrorPresentation: Identifiable {
    let id = UUID()
    let error: Error
    let context: String?
    let recoveryAction: (() -> Void)?
    
    var title: String {
        if let epilogueError = error as? EpilogueError {
            return String(epilogueError.errorDescription?.split(separator: ":").first ?? "Error")
        }
        return "Error"
    }
    
    var message: String {
        error.localizedDescription
    }
    
    var recoverySuggestion: String? {
        if let epilogueError = error as? EpilogueError {
            return epilogueError.recoverySuggestion
        }
        return nil
    }
}

struct ErrorRecord: Identifiable {
    let id = UUID()
    let error: Error
    let context: String?
    let timestamp: Date
}

// MARK: - Error Alert View Modifier

struct ErrorAlertModifier: ViewModifier {
    @StateObject private var errorService = ErrorHandlingService.shared
    
    func body(content: Content) -> some View {
        content
            .alert(item: $errorService.currentError) { errorPresentation in
                Alert(
                    title: Text(errorPresentation.title),
                    message: Text(buildMessage(for: errorPresentation)),
                    primaryButton: .default(Text("OK")) {
                        errorService.dismissError()
                    },
                    secondaryButton: errorPresentation.recoveryAction != nil ?
                        .default(Text("Retry")) {
                            errorPresentation.recoveryAction?()
                            errorService.dismissError()
                        } : .cancel()
                )
            }
    }
    
    private func buildMessage(for presentation: ErrorPresentation) -> String {
        var message = presentation.message
        if let suggestion = presentation.recoverySuggestion {
            message += "\n\n\(suggestion)"
        }
        return message
    }
}

extension View {
    func withErrorHandling() -> some View {
        modifier(ErrorAlertModifier())
    }
}

// MARK: - Async Error Handling

// MARK: - Convenience function for error handling
func withErrorHandling<T>(
    context: String,
    priority: TaskPriority? = nil,
    operation: @escaping () async throws -> T
) async -> T? {
    do {
        return try await operation()
    } catch {
        await ErrorHandlingService.shared.handle(error, context: context)
        return nil
    }
}

// MARK: - Debug Error View (for Settings)

struct ErrorHistoryDebugView: View {
    @StateObject private var errorService = ErrorHandlingService.shared
    
    var body: some View {
        List {
            Section("Error History") {
                if errorService.errorHistory.isEmpty {
                    Text("No errors recorded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(errorService.errorHistory) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.error.localizedDescription)
                                .font(.caption)
                                .lineLimit(2)
                            
                            HStack {
                                if let context = record.context {
                                    Text(context)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(record.timestamp, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            if !errorService.errorHistory.isEmpty {
                Section {
                    Button(role: .destructive) {
                        errorService.clearHistory()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Error History")
        .navigationBarTitleDisplayMode(.inline)
    }
}