import SwiftUI

// MARK: - Theme Selection View
/// Ultra-premium theme selection interface
struct ThemeSelectionView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme: GradientTheme
    @State private var showingPreview = false

    init() {
        _selectedTheme = State(initialValue: ThemeManager.shared.currentTheme)
    }

    var body: some View {
        ZStack {
            // Background with current theme
            ThemedGradientBackground()
                .ignoresSafeArea()
                .opacity(0.3)

            ScrollView {
                VStack(spacing: 24) {
                    // Preview Section
                    themePreviewCard
                        .padding(.top)

                    // Theme Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(GradientTheme.allCases, id: \.self) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: selectedTheme == theme,
                                isCurrent: themeManager.currentTheme == theme
                            ) {
                                selectTheme(theme)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Description
                    if selectedTheme != themeManager.currentTheme {
                        VStack(spacing: 12) {
                            Text("Tap to preview • Swipe to dismiss")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button {
                                applyTheme()
                            } label: {
                                Label("Apply Theme", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(selectedTheme.primaryAccent)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Gradient Themes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTheme != themeManager.currentTheme {
                    Button("Apply") {
                        applyTheme()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(selectedTheme.primaryAccent)
                }
            }
        }
    }

    // MARK: - Theme Preview Card
    private var themePreviewCard: some View {
        VStack(spacing: 16) {
            // Live preview
            RoundedRectangle(cornerRadius: 24)
                .fill(.black)
                .overlay {
                    ThemePreviewGradient(theme: selectedTheme)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                }
                .overlay {
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedTheme.displayName)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)

                                Text(selectedTheme.description)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                        }
                        .padding()
                        .background {
                            LinearGradient(
                                colors: [.black.opacity(0.7), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        }
                    }
                }
                .frame(height: 200)
                .padding(.horizontal)
                .shadow(radius: 20)
        }
    }

    // MARK: - Actions
    private func selectTheme(_ theme: GradientTheme) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedTheme = theme
        }

        // Light haptic on selection
        HapticManager.shared.lightTap()
    }

    private func applyTheme() {
        themeManager.setTheme(selectedTheme)

        // Force immediate dismiss to trigger view refresh
        DispatchQueue.main.async {
            dismiss()
        }
    }
}

// MARK: - Theme Card Component
struct ThemeCard: View {
    let theme: GradientTheme
    let isSelected: Bool
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Theme gradient preview
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black)
                    .overlay {
                        ThemePreviewGradient(theme: theme, compact: true)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .overlay {
                        if isCurrent {
                            VStack {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.white, theme.primaryAccent)
                                        .font(.title2)
                                        .padding(8)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(height: 120)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                isSelected ? theme.primaryAccent : Color.clear,
                                lineWidth: isSelected ? 3 : 0
                            )
                    }

                // Theme name and icon
                HStack(spacing: 6) {
                    Image(systemName: theme.icon)
                        .font(.caption)
                        .foregroundStyle(theme.primaryAccent)

                    Text(theme.displayName)
                        .font(.caption)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Theme Preview Gradient
struct ThemePreviewGradient: View {
    let theme: GradientTheme
    var compact: Bool = false
    @State private var animate = false

    var body: some View {
        let colors = theme.gradientColors

        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    colors[0].opacity(0.8),
                    colors[1].opacity(0.6),
                    colors[2].opacity(0.4),
                    colors[3].opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Animated accent blob
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            colors[1].opacity(0.6),
                            colors[2].opacity(0.3),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: compact ? 60 : 100
                    )
                )
                .scaleEffect(animate ? 1.2 : 0.8)
                .offset(x: animate ? 20 : -20, y: animate ? -20 : 20)
                .blur(radius: 20)

            // Secondary accent
            if !compact {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                colors[0].opacity(0.4),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .scaleEffect(animate ? 0.9 : 1.1)
                    .offset(x: animate ? -30 : 30, y: animate ? 30 : -30)
                    .blur(radius: 25)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: theme.animationDuration).repeatForever()) {
                animate = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ThemeSelectionView()
    }
    .preferredColorScheme(.dark)
}