import SwiftUI
import SwiftData

/// Compact inline card showing current reading progress
/// Displays at top of library when returning to the app
/// Note: Motion tracking removed for scroll performance
struct ReadingActivityCard: View {
    let book: BookModel
    let onContinue: () -> Void
    let onDismiss: () -> Void

    // Color extraction
    @State private var colorPalette: ColorPalette?
    @State private var enhancedColors: [Color] = []
    @State private var isVisible = false

    // Cache the UIImage to avoid recreating from data on each render
    @State private var cachedCoverImage: UIImage?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Welcome back"
        }
    }

    private var progressPercent: Double {
        guard let totalPages = book.pageCount, totalPages > 0 else { return 0 }
        return Double(book.currentPage) / Double(totalPages)
    }

    var body: some View {
        Button {
            continueReading()
        } label: {
            cardContent
        }
        .buttonStyle(ReadingActivityCardButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            // Cache the image once on appear
            if cachedCoverImage == nil, let data = book.coverImageData {
                cachedCoverImage = UIImage(data: data)
            }
            extractColors()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                isVisible = true
            }
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        HStack(spacing: 16) {
            // Book cover thumbnail
            bookCover

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Text(book.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(book.author)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)

                // Continue button
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Continue Reading")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.2)))
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(height: 160)
        .background(atmosphericBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            // Dismiss button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.black.opacity(0.3)))
            }
            .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .padding(.horizontal, 16)
    }

    // MARK: - Book Cover

    private var bookCover: some View {
        Group {
            if let image = cachedCoverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 120)
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(.white.opacity(0.15))
                        .frame(height: 4)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.9), .white.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geometry.size.width * progressPercent, 4), height: 4)
                }
            }
            .frame(height: 4)

            Text("\(Int(progressPercent * 100))% complete")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        Group {
            if enhancedColors.count >= 4 {
                ZStack {
                    // Rich multi-layer gradient from book colors (using pre-computed enhanced colors)
                    LinearGradient(
                        stops: [
                            .init(color: enhancedColors[0].opacity(0.95), location: 0.0),
                            .init(color: enhancedColors[1].opacity(0.7), location: 0.3),
                            .init(color: enhancedColors[2].opacity(0.5), location: 0.6),
                            .init(color: enhancedColors[3].opacity(0.4), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Radial accent glow
                    RadialGradient(
                        colors: [
                            enhancedColors[2].opacity(0.4),
                            Color.clear
                        ],
                        center: .topTrailing,
                        startRadius: 20,
                        endRadius: 200
                    )

                    // Subtle depth overlay
                    Color.black.opacity(0.1)
                }
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.15, blue: 0.3),
                        Color(red: 0.15, green: 0.12, blue: 0.25),
                        Color(red: 0.1, green: 0.1, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func enhanceColor(_ color: Color) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Boost saturation and ensure minimum brightness
        let enhancedSaturation = min(saturation * 1.3, 1.0)
        let enhancedBrightness = max(brightness, 0.4)

        return Color(hue: Double(hue), saturation: Double(enhancedSaturation), brightness: Double(enhancedBrightness))
    }

    // MARK: - Color Extraction

    private func extractColors() {
        guard let image = cachedCoverImage else { return }

        Task {
            let extractor = OKLABColorExtractor()
            if let palette = try? await extractor.extractPalette(from: image, imageSource: "reading_activity_card") {
                // Pre-compute enhanced colors on background thread
                let colors = [palette.primary, palette.secondary, palette.accent, palette.background]
                let enhanced = colors.map { enhanceColor($0) }

                await MainActor.run {
                    withAnimation(.easeIn(duration: 0.3)) {
                        colorPalette = palette
                        enhancedColors = enhanced
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func continueReading() {
        SensoryFeedback.medium()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onContinue()
        }
    }

    private func dismiss() {
        SensoryFeedback.light()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - Button Style

private struct ReadingActivityCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            // Mock card for preview
            Text("ReadingActivityCard Preview")
                .foregroundStyle(.white)
                .padding(.top, 100)

            Spacer()
        }
    }
    .modelContainer(for: BookModel.self)
}
