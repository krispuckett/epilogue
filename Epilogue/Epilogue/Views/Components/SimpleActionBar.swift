import SwiftUI

// MARK: - Simple Action Bar (Plus + Orb only)
struct SimpleActionBar: View {
    @Binding var showCard: Bool
    @EnvironmentObject var libraryViewModel: LibraryViewModel
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        HStack(spacing: 0) {
            // Plus button
            Button {
                SensoryFeedback.medium()
                showCard = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))
                .padding(.horizontal, 8)

            // Ambient orb
            Button {
                SensoryFeedback.light()
                if let currentBook = libraryViewModel.currentDetailBook {
                    SimplifiedAmbientCoordinator.shared.openAmbientReading(with: currentBook)
                } else {
                    SimplifiedAmbientCoordinator.shared.openAmbientReading()
                }
            } label: {
                AmbientOrbButton(size: 36) {
                    // Action handled by parent
                }
                .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryAccent.opacity(0.2),
                            themeManager.currentTheme.primaryAccent.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: themeManager.currentTheme.primaryAccent.opacity(0.1), radius: 8, y: 4)
    }
}