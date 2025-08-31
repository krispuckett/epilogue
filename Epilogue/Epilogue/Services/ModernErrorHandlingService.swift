import Foundation
import SwiftUI
import Observation
import os.log

// MARK: - Modern Error Handling Service using Observable Macro
// This is an example of migrating from ObservableObject to the new Observable macro

@MainActor
@Observable
final class ModernErrorHandlingService {
    static let shared = ModernErrorHandlingService()
    
    // Observable properties (no need for @Published)
    var currentError: ErrorPresentation?
    var errorHistory: [ErrorRecord] = []
    
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
            
            // Add haptic feedback for errors
            SensoryFeedback.error()
        }
    }
    
    /// Clear the current error presentation
    func clearCurrentError() {
        currentError = nil
    }
    
    /// Clear all error history
    func clearHistory() {
        errorHistory.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func shouldShowError(_ error: Error) -> Bool {
        // Don't show UI for certain recoverable errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled, .notConnectedToInternet:
                return false
            default:
                return true
            }
        }
        
        // Always show custom errors
        if error is EpilogueError {
            return true
        }
        
        // Default to showing
        return true
    }
}

// MARK: - Usage Example in View
/*
 With the new Observable macro, you use it differently in views:
 
 Old way (ObservableObject):
 ```swift
 struct MyView: View {
     @StateObject private var errorService = ErrorHandlingService.shared
     // or @EnvironmentObject var errorService: ErrorHandlingService
 }
 ```
 
 New way (Observable):
 ```swift
 struct MyView: View {
     // No need for property wrappers, just use the instance directly
     private let errorService = ModernErrorHandlingService.shared
     
     var body: some View {
         Text("Errors: \(errorService.errorHistory.count)")
             .alert(item: Bindable(errorService).currentError) { error in
                 Alert(
                     title: Text("Error"),
                     message: Text(error.error.localizedDescription),
                     dismissButton: .default(Text("OK"))
                 )
             }
     }
 }
 ```
 
 Key differences:
 1. No @Published needed - all stored properties are automatically observable
 2. Use @Observable instead of ObservableObject
 3. In views, use Bindable() wrapper when you need bindings
 4. Simpler mental model - just mark the class as @Observable
 */

// MARK: - Migration Guide
/*
 To migrate your ViewModels to Observable:
 
 1. Replace `ObservableObject` with `@Observable`
 2. Remove all `@Published` property wrappers
 3. In views, remove @StateObject/@ObservedObject/@EnvironmentObject
 4. Use `Bindable()` wrapper when you need $ bindings
 5. For environment objects, use the new Environment with key paths
 
 Benefits:
 - Better performance (only observes what's actually used)
 - Simpler code (less property wrappers)
 - More predictable behavior
 - Works better with Swift concurrency
 */