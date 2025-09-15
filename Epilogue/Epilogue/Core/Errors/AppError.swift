import Foundation
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "Error")

// MARK: - App Error Types

enum AppError: LocalizedError, Identifiable {
    case network(NetworkError)
    case data(DataError)
    case ai(AIError)
    case auth(AuthError)
    case validation(AppValidationError)
    case system(SystemError)
    case unknown(Error)

    // MARK: - Identifiable
    var id: String {
        switch self {
        case .network(let error): return "network-\(error.id)"
        case .data(let error): return "data-\(error.id)"
        case .ai(let error): return "ai-\(error.id)"
        case .auth(let error): return "auth-\(error.id)"
        case .validation(let error): return "validation-\(error.id)"
        case .system(let error): return "system-\(error.id)"
        case .unknown(let error): return "unknown-\(error.localizedDescription)"
        }
    }

    // MARK: - LocalizedError
    var errorDescription: String? {
        switch self {
        case .network(let error): return error.userMessage
        case .data(let error): return error.userMessage
        case .ai(let error): return error.userMessage
        case .auth(let error): return error.userMessage
        case .validation(let error): return error.userMessage
        case .system(let error): return error.userMessage
        case .unknown(let error): return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    var failureReason: String? {
        switch self {
        case .network(let error): return error.technicalDetails
        case .data(let error): return error.technicalDetails
        case .ai(let error): return error.technicalDetails
        case .auth(let error): return error.technicalDetails
        case .validation(let error): return error.technicalDetails
        case .system(let error): return error.technicalDetails
        case .unknown: return "Unknown error origin"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .network(let error): return error.recoverySuggestion
        case .data(let error): return error.recoverySuggestion
        case .ai(let error): return error.recoverySuggestion
        case .auth(let error): return error.recoverySuggestion
        case .validation(let error): return error.recoverySuggestion
        case .system(let error): return error.recoverySuggestion
        case .unknown: return "Please try again. If the problem persists, restart the app."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .network(let error): return error.isRetryable
        case .data(let error): return error.isRetryable
        case .ai(let error): return error.isRetryable
        case .auth(let error): return error.isRetryable
        case .validation: return false
        case .system(let error): return error.isRetryable
        case .unknown: return true
        }
    }

    // MARK: - Factory Methods
    static func from(_ error: Error) -> AppError {
        logger.error("Converting error to AppError: \(error.localizedDescription)")

        if let appError = error as? AppError {
            return appError
        }

        // Check for common system errors
        if let urlError = error as? URLError {
            return .network(.urlError(urlError))
        }

        // Check for SwiftData errors
        if error.localizedDescription.contains("SwiftData") ||
           error.localizedDescription.contains("ModelContainer") {
            return .data(.modelError(error))
        }

        return .unknown(error)
    }
}

// MARK: - Network Errors

enum NetworkError: Identifiable {
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case urlError(URLError)
    case invalidResponse
    case rateLimited(retryAfter: TimeInterval)

    var id: String {
        switch self {
        case .noConnection: return "no-connection"
        case .timeout: return "timeout"
        case .serverError(let code): return "server-\(code)"
        case .urlError(let error): return "url-\(error.code.rawValue)"
        case .invalidResponse: return "invalid-response"
        case .rateLimited: return "rate-limited"
        }
    }

    var userMessage: String {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "The request timed out"
        case .serverError(let code):
            return "Server error (\(code))"
        case .urlError(let error):
            return error.localizedDescription
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimited(let retryAfter):
            return "Too many requests. Please wait \(Int(retryAfter)) seconds."
        }
    }

    var technicalDetails: String {
        switch self {
        case .noConnection:
            return "Network is unreachable"
        case .timeout:
            return "Request exceeded timeout threshold"
        case .serverError(let code):
            return "HTTP status code: \(code)"
        case .urlError(let error):
            return "URLError code: \(error.code.rawValue)"
        case .invalidResponse:
            return "Response validation failed"
        case .rateLimited(let retryAfter):
            return "Rate limit exceeded, retry after: \(retryAfter)s"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .noConnection:
            return "Check your internet connection and try again"
        case .timeout:
            return "Check your connection speed and try again"
        case .serverError:
            return "The server is having issues. Please try again later."
        case .urlError:
            return "Check your network settings"
        case .invalidResponse:
            return "Try updating the app to the latest version"
        case .rateLimited:
            return "Please wait before making more requests"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError, .rateLimited:
            return true
        case .urlError, .invalidResponse:
            return false
        }
    }
}

// MARK: - Data Errors

enum DataError: Identifiable {
    case notFound
    case corrupted
    case migrationFailed
    case modelError(Error)
    case syncConflict
    case diskFull

    var id: String {
        switch self {
        case .notFound: return "not-found"
        case .corrupted: return "corrupted"
        case .migrationFailed: return "migration-failed"
        case .modelError: return "model-error"
        case .syncConflict: return "sync-conflict"
        case .diskFull: return "disk-full"
        }
    }

    var userMessage: String {
        switch self {
        case .notFound:
            return "Data not found"
        case .corrupted:
            return "Data appears to be corrupted"
        case .migrationFailed:
            return "Failed to update data format"
        case .modelError:
            return "Error accessing data"
        case .syncConflict:
            return "Sync conflict detected"
        case .diskFull:
            return "Not enough storage space"
        }
    }

    var technicalDetails: String {
        switch self {
        case .notFound:
            return "Requested data entity not found in store"
        case .corrupted:
            return "Data integrity check failed"
        case .migrationFailed:
            return "SwiftData migration process failed"
        case .modelError(let error):
            return "Model error: \(error.localizedDescription)"
        case .syncConflict:
            return "CloudKit sync conflict"
        case .diskFull:
            return "Insufficient disk space for operation"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .notFound:
            return "The item may have been deleted"
        case .corrupted:
            return "Try restoring from iCloud backup"
        case .migrationFailed:
            return "Reinstall the app to fix this issue"
        case .modelError:
            return "Restart the app and try again"
        case .syncConflict:
            return "Your changes will be synced when possible"
        case .diskFull:
            return "Free up some space on your device"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .notFound, .corrupted, .migrationFailed, .diskFull:
            return false
        case .modelError, .syncConflict:
            return true
        }
    }
}

// MARK: - AI Errors

enum AIError: Identifiable {
    case unavailable
    case quotaExceeded
    case invalidInput
    case processingFailed
    case modelNotLoaded

    var id: String {
        switch self {
        case .unavailable: return "unavailable"
        case .quotaExceeded: return "quota-exceeded"
        case .invalidInput: return "invalid-input"
        case .processingFailed: return "processing-failed"
        case .modelNotLoaded: return "model-not-loaded"
        }
    }

    var userMessage: String {
        switch self {
        case .unavailable:
            return "AI service is currently unavailable"
        case .quotaExceeded:
            return "AI usage limit reached"
        case .invalidInput:
            return "Invalid input for AI processing"
        case .processingFailed:
            return "AI processing failed"
        case .modelNotLoaded:
            return "AI model is still loading"
        }
    }

    var technicalDetails: String {
        switch self {
        case .unavailable:
            return "Foundation Models service unavailable"
        case .quotaExceeded:
            return "API quota limit exceeded"
        case .invalidInput:
            return "Input validation failed for AI model"
        case .processingFailed:
            return "Model inference failed"
        case .modelNotLoaded:
            return "Model initialization incomplete"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .unavailable:
            return "AI features will be available soon"
        case .quotaExceeded:
            return "Wait for quota to reset or upgrade your plan"
        case .invalidInput:
            return "Check your input and try again"
        case .processingFailed:
            return "Try rephrasing your request"
        case .modelNotLoaded:
            return "Please wait a moment and try again"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .unavailable, .modelNotLoaded, .processingFailed:
            return true
        case .quotaExceeded, .invalidInput:
            return false
        }
    }
}

// MARK: - Auth Errors

enum AuthError: Identifiable {
    case notAuthenticated
    case invalidCredentials
    case tokenExpired
    case permissionDenied

    var id: String {
        switch self {
        case .notAuthenticated: return "not-authenticated"
        case .invalidCredentials: return "invalid-credentials"
        case .tokenExpired: return "token-expired"
        case .permissionDenied: return "permission-denied"
        }
    }

    var userMessage: String {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .invalidCredentials:
            return "Invalid credentials"
        case .tokenExpired:
            return "Session expired"
        case .permissionDenied:
            return "Permission denied"
        }
    }

    var technicalDetails: String {
        switch self {
        case .notAuthenticated:
            return "No valid authentication session"
        case .invalidCredentials:
            return "Authentication failed with provided credentials"
        case .tokenExpired:
            return "Authentication token has expired"
        case .permissionDenied:
            return "Insufficient permissions for requested operation"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .notAuthenticated, .tokenExpired:
            return "Please sign in again"
        case .invalidCredentials:
            return "Check your credentials and try again"
        case .permissionDenied:
            return "Contact support if you believe this is an error"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .invalidCredentials, .permissionDenied:
            return false
        case .notAuthenticated, .tokenExpired:
            return true
        }
    }
}

// MARK: - Validation Errors

enum AppValidationError: Identifiable {
    case required(field: String)
    case invalid(field: String, reason: String)
    case tooLong(field: String, maxLength: Int)
    case tooShort(field: String, minLength: Int)

    var id: String {
        switch self {
        case .required(let field): return "required-\(field)"
        case .invalid(let field, _): return "invalid-\(field)"
        case .tooLong(let field, _): return "too-long-\(field)"
        case .tooShort(let field, _): return "too-short-\(field)"
        }
    }

    var userMessage: String {
        switch self {
        case .required(let field):
            return "\(field) is required"
        case .invalid(let field, let reason):
            return "\(field) is invalid: \(reason)"
        case .tooLong(let field, let max):
            return "\(field) is too long (max \(max) characters)"
        case .tooShort(let field, let min):
            return "\(field) is too short (min \(min) characters)"
        }
    }

    var technicalDetails: String {
        userMessage // Same as user message for validation
    }

    var recoverySuggestion: String {
        switch self {
        case .required(let field):
            return "Please provide a value for \(field)"
        case .invalid(let field, _):
            return "Please check the \(field) and try again"
        case .tooLong(let field, let max):
            return "Shorten \(field) to \(max) characters or less"
        case .tooShort(let field, let min):
            return "Make \(field) at least \(min) characters long"
        }
    }

    var isRetryable: Bool { false }
}

// MARK: - System Errors

enum SystemError: Identifiable {
    case fileSystem(Error)
    case memory
    case background
    case permission(String)

    var id: String {
        switch self {
        case .fileSystem: return "file-system"
        case .memory: return "memory"
        case .background: return "background"
        case .permission(let type): return "permission-\(type)"
        }
    }

    var userMessage: String {
        switch self {
        case .fileSystem:
            return "File system error"
        case .memory:
            return "Memory issue detected"
        case .background:
            return "Background processing error"
        case .permission(let type):
            return "\(type) permission required"
        }
    }

    var technicalDetails: String {
        switch self {
        case .fileSystem(let error):
            return "File system error: \(error.localizedDescription)"
        case .memory:
            return "Memory pressure detected"
        case .background:
            return "Background task failed"
        case .permission(let type):
            return "Missing permission: \(type)"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .fileSystem:
            return "Check available storage space"
        case .memory:
            return "Close other apps and try again"
        case .background:
            return "Keep the app open to complete the task"
        case .permission(let type):
            return "Grant \(type) permission in Settings"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .fileSystem, .memory, .background:
            return true
        case .permission:
            return false
        }
    }
}