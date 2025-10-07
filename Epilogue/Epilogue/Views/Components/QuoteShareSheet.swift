import SwiftUI

/// Sheet for sharing quotes with gradient selection - matching app design language
struct QuoteShareSheet: View {
    let quote: String
    let author: String?
    let bookTitle: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedGradient: ShareGradientTheme = .amber
    @State private var isSharing = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Ambient gradient background - matching BookSearchSheet
                ambientGradientBackground

                VStack(spacing: 0) {
                    // Preview area
                    ScrollView {
                        VStack(spacing: 32) {
                            // Quote card preview
                            previewCard
                                .padding(.top, 24)

                            // Gradient picker
                            gradientPicker
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 120) // Space for share button
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Share Quote")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .safeAreaBar(edge: .bottom) {
                shareButton
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
    }

    // MARK: - Ambient Gradient Background
    private var ambientGradientBackground: some View {
        ZStack {
            AmbientChatGradientView()
                .opacity(0.4)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            Color.black.opacity(0.15)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Preview Card - Matching note card design
    private var previewCard: some View {
        ZStack {
            // Black base
            Color.black

            // Atmospheric gradient background
            let colors = selectedGradient.gradientColors
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: colors[0].opacity(0.85), location: 0.0),
                        .init(color: colors[1].opacity(0.65), location: 0.15),
                        .init(color: colors[2].opacity(0.45), location: 0.3),
                        .init(color: Color.clear, location: 0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.4),
                        .init(color: colors[2].opacity(0.35), location: 0.7),
                        .init(color: colors[1].opacity(0.5), location: 0.85),
                        .init(color: colors[3].opacity(0.65), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Content layout matching note card EXACTLY
            VStack(alignment: .leading, spacing: 0) {
                // Flexible top spacer (shrinks for long quotes)
                Spacer()
                    .frame(minHeight: 0, idealHeight: 40, maxHeight: 40)

                // Large transparent curly quote - subtle
                Text("\u{201C}")
                    .font(.custom("Georgia", size: 80))
                    .foregroundStyle(.white.opacity(0.3))
                    .offset(x: -10, y: 20)
                    .frame(height: 0)

                // Quote content with drop cap
                HStack(alignment: .top, spacing: 0) {
                    // Drop cap
                    Text(String(quote.prefix(1)))
                        .font(.custom("Georgia", size: 56))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .padding(.trailing, 4)
                        .offset(y: -8)

                    // Rest of quote
                    Text(String(quote.dropFirst()))
                        .font(.custom("Georgia", size: 24))
                        .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96))
                        .lineSpacing(11)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
                .padding(.top, 20)

                // Flexible middle spacer (shrinks for long quotes)
                Spacer()
                    .frame(minHeight: 20)

                // Attribution section (always visible at bottom)
                VStack(alignment: .leading, spacing: 16) {
                    // Thin horizontal rule with gradient
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 0),
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(1.0), location: 0.5),
                            .init(color: Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.1), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 0.5)
                    .padding(.top, 28)

                    // Attribution text
                    VStack(alignment: .leading, spacing: 8) {
                        if let author = author, !author.isEmpty {
                            Text(author.uppercased())
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .kerning(1.5)
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.8))
                        }

                        if let bookTitle = bookTitle, !bookTitle.isEmpty {
                            Text(bookTitle.uppercased())
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .kerning(1.2)
                                .foregroundStyle(Color(red: 0.98, green: 0.97, blue: 0.96).opacity(0.6))
                        }
                    }
                }
            }
            .padding(32)
        }
        .frame(width: 340, height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Gradient Picker
    private var gradientPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Background")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ShareGradientTheme.allCases) { theme in
                        gradientOption(theme: theme)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private func gradientOption(theme: ShareGradientTheme) -> some View {
        Button {
            withAnimation(DesignSystem.Animation.springStandard) {
                selectedGradient = theme
            }
            SensoryFeedback.light()
        } label: {
            VStack(spacing: 8) {
                // Atmospheric gradient swatch - matching preview
                ZStack {
                    Color.black

                    let colors = theme.gradientColors
                    ZStack {
                        LinearGradient(
                            stops: [
                                .init(color: colors[0].opacity(0.85), location: 0.0),
                                .init(color: colors[1].opacity(0.65), location: 0.15),
                                .init(color: colors[2].opacity(0.45), location: 0.3),
                                .init(color: Color.clear, location: 0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        LinearGradient(
                            stops: [
                                .init(color: Color.clear, location: 0.4),
                                .init(color: colors[2].opacity(0.35), location: 0.7),
                                .init(color: colors[1].opacity(0.5), location: 0.85),
                                .init(color: colors[3].opacity(0.65), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            selectedGradient == theme ? Color.white.opacity(0.5) : Color.white.opacity(0.15),
                            lineWidth: selectedGradient == theme ? 2 : 1
                        )
                        .allowsHitTesting(false)
                }

                // Label
                Text(theme.rawValue)
                    .font(.system(size: 12, weight: selectedGradient == theme ? .semibold : .medium))
                    .foregroundStyle(selectedGradient == theme ? .white : .white.opacity(0.7))
            }
        }
        .scaleEffect(selectedGradient == theme ? 1.05 : 1.0)
        .animation(DesignSystem.Animation.springStandard, value: selectedGradient)
    }

    // MARK: - Share Button
    private var shareButton: some View {
        Button {
            shareQuoteImage()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))

                Text("Share Quote")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .frame(height: 48)
        }
        .disabled(isSharing)
        .opacity(isSharing ? 0.6 : 1.0)
        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, DesignSystem.Spacing.inlinePadding)
        .padding(.bottom, 8)
    }

    private func shareQuoteImage() {
        isSharing = true
        SensoryFeedback.medium()

        Task { @MainActor in
            // Render full-size quote card
            let fullSizeCard = ShareableQuoteCard(
                quote: quote,
                author: author,
                bookTitle: bookTitle,
                gradient: selectedGradient
            )

            // Render to image
            let image = if #available(iOS 16.0, *) {
                ImageRenderer.renderModern(
                    view: fullSizeCard,
                    size: CGSize(width: 1080, height: 1080)
                )
            } else {
                ImageRenderer.render(
                    view: fullSizeCard,
                    size: CGSize(width: 1080, height: 1080)
                )
            }

            // Share
            let activityController = UIActivityViewController(
                activityItems: [image],
                applicationActivities: nil
            )

            // Present share sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                // Find the topmost presented view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                activityController.completionWithItemsHandler = { _, completed, _, _ in
                    isSharing = false
                    if completed {
                        SensoryFeedback.success()
                        // Dismiss the sheet after successful share
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            dismiss()
                        }
                    }
                }

                topController.present(activityController, animated: true)
            } else {
                isSharing = false
            }
        }
    }
}

// MARK: - Preview
#Preview {
    QuoteShareSheet(
        quote: "It is our choices, Harry, that show what we truly are, far more than our abilities.",
        author: "Albus Dumbledore",
        bookTitle: "Harry Potter and the Chamber of Secrets"
    )
}
