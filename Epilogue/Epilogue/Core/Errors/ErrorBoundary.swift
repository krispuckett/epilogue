import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.epilogue", category: "ErrorBoundary")

// MARK: - Error Boundary View Modifier

struct ErrorBoundary: ViewModifier {
    @State private var error: AppError?
    @State private var retryCount = 0
    let maxRetries = 3

    let action: () async throws -> Void

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: Binding<Bool>(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                if let error = error {
                    // Retry button if applicable
                    if error.isRetryable && retryCount < maxRetries {
                        Button("Retry") {
                            Task {
                                await retry()
                            }
                        }
                    }

                    // Dismiss button
                    Button("Dismiss", role: .cancel) {
                        self.error = nil
                        retryCount = 0
                    }
                }
            } message: {
                if let error = error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error.errorDescription ?? "Unknown error")

                        if let suggestion = error.recoverySuggestion {
                            Text(suggestion)
                                .font(.caption)
                        }

                        if retryCount > 0 {
                            Text("Retry attempt \(retryCount) of \(maxRetries)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .task {
                await performAction()
            }
    }

    @MainActor
    private func performAction() async {
        do {
            try await action()
        } catch {
            logger.error("Error in boundary: \(error.localizedDescription)")
            self.error = AppError.from(error)
        }
    }

    @MainActor
    private func retry() async {
        retryCount += 1
        logger.info("Retrying action, attempt \(retryCount)")

        // Exponential backoff
        let delay = pow(2.0, Double(retryCount - 1))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        await performAction()
    }
}

// MARK: - Async Error Boundary

struct AsyncErrorBoundary<Content: View>: View {
    @State private var error: AppError?
    @State private var isLoading = true

    let action: () async throws -> Void
    let content: () -> Content

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .task {
                        await load()
                    }
            } else if let error = error {
                ErrorView(error: error) {
                    Task {
                        await load()
                    }
                }
            } else {
                content()
            }
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil

        do {
            try await action()
            isLoading = false
        } catch {
            logger.error("Async boundary error: \(error.localizedDescription)")
            self.error = AppError.from(error)
            isLoading = false
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let error: AppError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundStyle(iconColor)

            VStack(spacing: 8) {
                Text(error.errorDescription ?? "Something went wrong")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if error.isRetryable {
                Button(action: retry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var iconName: String {
        switch error {
        case .network: return "wifi.exclamationmark"
        case .data: return "exclamationmark.triangle"
        case .ai: return "brain"
        case .auth: return "lock.fill"
        case .validation: return "exclamationmark.circle"
        case .system: return "gear.badge.xmark"
        case .unknown: return "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch error {
        case .network: return .orange
        case .data: return .red
        case .ai: return .purple
        case .auth: return .blue
        case .validation: return .yellow
        case .system: return .gray
        case .unknown: return .secondary
        }
    }
}

// MARK: - View Extensions

extension View {
    func withErrorHandling(action: @escaping () async throws -> Void = {}) -> some View {
        modifier(ErrorBoundary(action: action))
    }

    func asyncErrorBoundary<Content: View>(
        action: @escaping () async throws -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        AsyncErrorBoundary(action: action, content: content)
    }
}

// MARK: - Error Alert Modifier

struct ErrorBoundaryAlertModifier: ViewModifier {
    @Binding var error: AppError?

    func body(content: Content) -> some View {
        content
            .alert(
                "Error",
                isPresented: Binding<Bool>(
                    get: { error != nil },
                    set: { if !$0 { error = nil } }
                ),
                presenting: error
            ) { error in
                if error.isRetryable {
                    Button("Retry") {
                        // Retry logic would be handled by the view
                    }
                }
                Button("OK", role: .cancel) {
                    self.error = nil
                }
            } message: { error in
                VStack(alignment: .leading) {
                    Text(error.errorDescription ?? "An error occurred")
                    if let suggestion = error.recoverySuggestion {
                        Text(suggestion)
                            .font(.caption)
                    }
                }
            }
    }
}

extension View {
    func errorAlert(_ error: Binding<AppError?>) -> some View {
        modifier(ErrorBoundaryAlertModifier(error: error))
    }
}