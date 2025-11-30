import SwiftUI
import SwiftData

/// Developer experiment comparing legacy ColorPalette gradients vs new OKLCH DisplayPalette system
/// Access from Settings > Developer Options
struct OKLCHGradientExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // State
    @State private var selectedBook: BookModel?
    @State private var showBookPicker = false
    @State private var showControls = true

    // Legacy palette
    @State private var legacyPalette: ColorPalette?
    @State private var isExtractingLegacy = false

    // New OKLCH palette
    @State private var displayPalette: DisplayPalette?
    @State private var isExtractingOKLCH = false

    // Display mode
    @State private var displayMode: DisplayMode = .sideBySide
    @State private var gradientIntensity: Double = 1.0

    enum DisplayMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case legacy = "Legacy Only"
        case oklch = "OKLCH Only"
        case overlay = "Overlay"
    }

    // Books with covers
    private var booksWithCovers: [BookModel] {
        books.filter { $0.coverImageData != nil }
    }

    private var targetBook: BookModel? {
        selectedBook ?? booksWithCovers.first
    }

    private var bookCoverImage: UIImage? {
        guard let book = targetBook,
              let imageData = book.coverImageData else {
            return nil
        }
        return UIImage(data: imageData)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch displayMode {
                case .sideBySide:
                    sideBySideView
                case .legacy:
                    legacyGradientView
                case .oklch:
                    oklchGradientView
                case .overlay:
                    overlayComparisonView
                }

                // Book cover and info overlay
                VStack {
                    bookInfoHeader
                    Spacer()
                    if showControls {
                        controlsPanel
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showBookPicker = true } label: {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Button { showControls.toggle() } label: {
                            Image(systemName: showControls ? "eye.slash" : "eye")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .sheet(isPresented: $showBookPicker) {
                bookPickerSheet
            }
            .onChange(of: targetBook) { _, newBook in
                if newBook != nil {
                    extractColors()
                }
            }
            .onAppear {
                extractColors()
            }
        }
    }

    // MARK: - Side by Side View

    @ViewBuilder
    private var sideBySideView: some View {
        HStack(spacing: 0) {
            // Legacy (left)
            ZStack {
                if let palette = legacyPalette {
                    BookAtmosphericGradientView(
                        colorPalette: palette,
                        intensity: gradientIntensity
                    )
                } else {
                    Color.black
                }
                VStack {
                    Text("LEGACY")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 120)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1)

            // OKLCH (right)
            ZStack {
                if let palette = displayPalette {
                    UnifiedAtmosphericGradient(
                        palette: palette,
                        preset: .atmospheric,
                        intensity: gradientIntensity
                    )
                } else {
                    Color.black
                }
                VStack {
                    Text("OKLCH")
                        .font(.caption2.bold())
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 120)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Single Views

    @ViewBuilder
    private var legacyGradientView: some View {
        if let palette = legacyPalette {
            BookAtmosphericGradientView(
                colorPalette: palette,
                intensity: gradientIntensity
            )
        } else {
            loadingView
        }
    }

    @ViewBuilder
    private var oklchGradientView: some View {
        if let palette = displayPalette {
            UnifiedAtmosphericGradient(
                palette: palette,
                preset: .atmospheric,
                intensity: gradientIntensity
            )
        } else {
            loadingView
        }
    }

    @ViewBuilder
    private var overlayComparisonView: some View {
        ZStack {
            // Legacy at 50% opacity
            if let palette = legacyPalette {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: gradientIntensity
                )
                .opacity(0.5)
            }
            // OKLCH at 50% opacity with blend
            if let palette = displayPalette {
                UnifiedAtmosphericGradient(
                    palette: palette,
                    preset: .atmospheric,
                    intensity: gradientIntensity
                )
                .opacity(0.5)
                .blendMode(.plusLighter)
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack {
            ProgressView()
                .tint(.white)
            Text("Extracting colors...")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Book Info Header

    @ViewBuilder
    private var bookInfoHeader: some View {
        VStack(spacing: 16) {
            // Cover image
            if let image = bookCoverImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.5), radius: 20)
            }

            // Book title
            if let book = targetBook {
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }

            // Palette info
            if let dp = displayPalette {
                VStack(spacing: 4) {
                    Text("Cover Type: \(dp.coverType.rawValue.capitalized)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    // Color swatches
                    HStack(spacing: 8) {
                        colorSwatch(dp.primary.color, label: "P")
                        colorSwatch(dp.secondary.color, label: "S")
                        colorSwatch(dp.accent.color, label: "A")
                        colorSwatch(dp.background.color, label: "B")
                    }
                }
            }
        }
        .padding(.top, 60)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func colorSwatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Controls Panel

    @ViewBuilder
    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // Display mode picker
            Picker("Display Mode", selection: $displayMode) {
                ForEach(DisplayMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Intensity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Intensity")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.0f%%", gradientIntensity * 100))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }
                Slider(value: $gradientIntensity, in: 0...1.5)
                    .tint(.white)
            }

            // Re-extract button
            Button {
                extractColors()
            } label: {
                HStack {
                    if isExtractingLegacy || isExtractingOKLCH {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text("Re-extract Colors")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isExtractingLegacy || isExtractingOKLCH)

            // Debug info
            if let dp = displayPalette {
                VStack(alignment: .leading, spacing: 2) {
                    Text("OKLCH Primary: L=\(String(format: "%.2f", dp.primary.lightness)) C=\(String(format: "%.2f", dp.primary.chroma)) H=\(String(format: "%.0f", dp.primary.hue))°")
                    Text("Confidence: \(String(format: "%.0f%%", dp.extractionConfidence * 100))")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    // MARK: - Book Picker Sheet

    @ViewBuilder
    private var bookPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                    ForEach(booksWithCovers) { book in
                        Button {
                            selectedBook = book
                            showBookPicker = false
                        } label: {
                            VStack(spacing: 4) {
                                if let data = book.coverImageData,
                                   let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 70, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(selectedBook?.id == book.id ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                }
                                Text(book.title)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.primary)
                            }
                            .frame(width: 80)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showBookPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Color Extraction

    private func extractColors() {
        guard let book = targetBook,
              let imageData = book.coverImageData,
              let image = UIImage(data: imageData) else {
            return
        }

        let bookID = book.id

        // Extract legacy palette
        isExtractingLegacy = true
        Task {
            let extractor = OKLABColorExtractor()
            do {
                let palette = try await extractor.extractPalette(from: image, imageSource: bookID)
                await MainActor.run {
                    self.legacyPalette = palette
                    self.isExtractingLegacy = false
                }
            } catch {
                await MainActor.run {
                    self.isExtractingLegacy = false
                }
            }
        }

        // Extract OKLCH palette using legacy extractor (stable)
        isExtractingOKLCH = true
        Task {
            let legacyExtractor = OKLABColorExtractor()
            do {
                let legacyPalette = try await legacyExtractor.extractPalette(from: image, imageSource: bookID)
                let palette = DisplayPalette.fromLegacy(legacyPalette)
                await MainActor.run {
                    self.displayPalette = palette
                    self.isExtractingOKLCH = false
                }
            } catch {
                // Fallback on error
                await MainActor.run {
                    self.isExtractingOKLCH = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OKLCHGradientExperiment()
}
