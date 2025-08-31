import SwiftUI

// MARK: - Modern Empty States using iOS 26 ContentUnavailableView
struct ModernEmptyStates {
    
    // MARK: - Library Empty State
    static func noBooks(addAction: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label("Your Library is Empty", systemImage: "books.vertical")
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        } description: {
            Text("Add your first book to start tracking your reading journey")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        } actions: {
            Button(action: addAction) {
                Label("Add Book", systemImage: "plus.circle.fill")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignSystem.Colors.primaryAccent)
        }
    }
    
    // MARK: - Notes Empty State
    static var noNotes: some View {
        ContentUnavailableView {
            Label("No Notes Yet", systemImage: "note.text")
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        } description: {
            Text("Start capturing your thoughts, quotes, and questions from your reading journey")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Sessions Empty State
    static var noSessions: some View {
        ContentUnavailableView {
            Label("No Reading Sessions", systemImage: "clock.arrow.circlepath")
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        } description: {
            Text("Your reading sessions will appear here once you start tracking")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Search Empty State
    static func noSearchResults(searchText: String) -> some View {
        ContentUnavailableView.search(text: searchText)
            .foregroundStyle(DesignSystem.Colors.textPrimary, DesignSystem.Colors.textSecondary)
    }
    
    // MARK: - Chat Empty State
    static var noChatHistory: some View {
        ContentUnavailableView {
            Label("No Conversations", systemImage: "bubble.left.and.bubble.right")
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        } description: {
            Text("Start a conversation about your books")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Quotes Empty State
    static var noQuotes: some View {
        ContentUnavailableView {
            Label("No Quotes Saved", systemImage: "quote.opening")
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        } description: {
            Text("Save memorable passages from your reading")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Import Empty State
    static var noImportedBooks: some View {
        ContentUnavailableView {
            Label("No Books to Import", systemImage: "square.and.arrow.down")
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        } description: {
            Text("We couldn't find any books to import from this source")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
    
    // MARK: - Network Error State
    static func networkError(retry: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "wifi.exclamationmark")
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        } description: {
            Text("Check your internet connection and try again")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        } actions: {
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(DesignSystem.Colors.primaryAccent)
        }
    }
    
    // MARK: - Loading State (while not empty, useful for consistency)
    static var loading: some View {
        ContentUnavailableView {
            ProgressView()
                .controlSize(.large)
                .padding(.bottom, 8)
            Text("Loading...")
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }
}

// MARK: - Glass Effect Empty State Wrapper
struct GlassEmptyStateContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Subtle background gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.surfaceBackground,
                    DesignSystem.Colors.surfaceBackground.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Glass container for empty state
            content
                .padding(DesignSystem.Spacing.lg)
                .frame(maxWidth: 400)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large))
        }
    }
}

// MARK: - Preview Provider
#Preview("Empty States Gallery") {
    ScrollView {
        VStack(spacing: 40) {
            // Library Empty
            GlassEmptyStateContainer {
                ModernEmptyStates.noBooks(addAction: {})
            }
            .frame(height: 300)
            
            // Notes Empty
            GlassEmptyStateContainer {
                ModernEmptyStates.noNotes
            }
            .frame(height: 250)
            
            // Search Empty
            GlassEmptyStateContainer {
                ModernEmptyStates.noSearchResults(searchText: "Tolkien")
            }
            .frame(height: 250)
            
            // Network Error
            GlassEmptyStateContainer {
                ModernEmptyStates.networkError(retry: {})
            }
            .frame(height: 280)
        }
        .padding()
    }
    .background(DesignSystem.Colors.surfaceBackground)
    .preferredColorScheme(.dark)
}