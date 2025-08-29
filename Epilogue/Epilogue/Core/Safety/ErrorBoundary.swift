import SwiftUI
import Combine

// MARK: - Error Boundary View
struct ErrorBoundary<Content: View>: View {
    @State private var hasError = false
    @State private var errorMessage = ""
    let content: () -> Content
    
    var body: some View {
        Group {
            if hasError {
                ErrorFallbackView(
                    errorMessage: errorMessage,
                    onRetry: {
                        hasError = false
                        errorMessage = ""
                    }
                )
            } else {
                content()
                    .onAppear {
                        // Set up global error catching if needed
                    }
            }
        }
    }
}

// MARK: - Error Fallback View
struct ErrorFallbackView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(errorMessage.isEmpty ? "An unexpected error occurred" : errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
}

// MARK: - View Extension for Error Handling
extension View {
    func withSafeErrorHandling() -> some View {
        ErrorBoundary {
            self
        }
    }
}

// MARK: - Safe Task Wrapper
struct SafeTask<Content: View>: View {
    let priority: _Concurrency.TaskPriority
    let action: () async throws -> Void
    let content: Content
    @State private var taskHandle: Task<Void, Never>?
    @State private var hasError = false
    
    init(
        priority: _Concurrency.TaskPriority = .medium,
        action: @escaping () async throws -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.priority = priority
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        content
            .onAppear {
                taskHandle = Task(priority: priority) {
                    do {
                        try await action()
                    } catch {
                        print("❌ SafeTask error: \(error)")
                        await MainActor.run {
                            hasError = true
                        }
                    }
                }
            }
            .onDisappear {
                taskHandle?.cancel()
            }
    }
}

// MARK: - Crash Prevention Manager
@MainActor
class CrashPreventionManager: ObservableObject {
    static let shared = CrashPreventionManager()
    
    @Published var hasGlobalError = false
    @Published var globalErrorMessage = ""
    
    private init() {
        setupGlobalErrorHandling()
    }
    
    private func setupGlobalErrorHandling() {
        // Set up NSSetUncaughtExceptionHandler for Objective-C exceptions
        NSSetUncaughtExceptionHandler { exception in
            print("🚨 Uncaught exception: \(exception)")
            print("📍 Call stack: \(exception.callStackSymbols)")
            
            // Log to crash reporting service if available
            Task { @MainActor in
                CrashPreventionManager.shared.hasGlobalError = true
                CrashPreventionManager.shared.globalErrorMessage = exception.reason ?? "Unknown error"
            }
        }
    }
    
    func logError(_ error: Error, context: String = "") {
        print("❌ Error in \(context): \(error)")
        // Add crash reporting service here if needed
    }
    
    func logWarning(_ message: String) {
        print("⚠️ Warning: \(message)")
    }
}

// MARK: - Safe Navigation
struct SafeNavigationLink<Label: View, Destination: View>: View {
    let destination: () -> Destination?
    let label: Label
    @State private var isActive = false
    @State private var hasError = false
    
    init(
        destination: @escaping () -> Destination?,
        @ViewBuilder label: () -> Label
    ) {
        self.destination = destination
        self.label = label()
    }
    
    var body: some View {
        NavigationLink(
            destination: Group {
                if let dest = destination() {
                    dest
                        .withSafeErrorHandling()
                } else {
                    ErrorFallbackView(
                        errorMessage: "Unable to load this screen",
                        onRetry: {
                            isActive = false
                        }
                    )
                }
            },
            isActive: $isActive
        ) {
            label
        }
    }
}

// MARK: - Safe Sheet Presentation
struct SafeSheet<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: () -> SheetContent
    @State private var hasError = false
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ErrorBoundary {
                    self.sheetContent()
                }
            }
    }
}

extension View {
    func safeSheet<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(SafeSheet(isPresented: isPresented, sheetContent: content))
    }
}