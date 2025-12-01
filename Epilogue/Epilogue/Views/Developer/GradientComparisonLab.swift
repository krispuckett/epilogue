import SwiftUI
import SwiftData

/// Developer tool for comparing current vs intelligent gradient extraction
/// Access from Settings > Developer Options > Gradient Comparison Lab
struct GradientComparisonLab: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // State
    @State private var selectedBook: BookModel?
    @State private var showBookPicker = false
    @State private var comparisonMode: ComparisonMode = .sideBySide
    @State private var showDebugInfo = true
    @State private var isExtracting = false

    // Current system results
    @State private var currentPalette: ColorPalette?
    @State private var currentExtractionTime: Double = 0

    // Intelligent system results
    @State private var intelligentPalette: IntelligentColorExtractor.IntelligentPalette?
    @State private var intelligentExtractionTime: Double = 0

    enum ComparisonMode: String, CaseIterable {
        case sideBySide = "Side by Side"
        case toggle = "Toggle"
        case overlay = "Overlay"
    }

    private var booksWithCovers: [BookModel] {
        books.filter { $0.coverImageData != nil }
    }

    private var targetBook: BookModel? {
        selectedBook ?? booksWithCovers.first { $0.title.lowercased().contains("lord of the rings") }
            ?? booksWithCovers.first
    }

    private var bookImage: UIImage? {
        guard let data = targetBook?.coverImageData else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Comparison area
                    comparisonArea
                        .frame(maxHeight: .infinity)

                    // Controls
                    controlsPanel
                }
            }
            .navigationTitle("Gradient Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBookPicker = true
                    } label: {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .sheet(isPresented: $showBookPicker) {
                bookPickerSheet
            }
            .task {
                await extractBothSystems()
            }
            .onChange(of: selectedBook) { _, _ in
                Task { await extractBothSystems() }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Comparison Area

    @ViewBuilder
    private var comparisonArea: some View {
        if let book = targetBook, let image = bookImage {
            switch comparisonMode {
            case .sideBySide:
                sideBySideView(book: book, image: image)
            case .toggle:
                toggleView(book: book, image: image)
            case .overlay:
                overlayView(book: book, image: image)
            }
        } else {
            noBookView
        }
    }

    private func sideBySideView(book: BookModel, image: UIImage) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                // Current system
                VStack(spacing: 0) {
                    Text("CURRENT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)

                    ZStack {
                        if let palette = currentPalette {
                            BookAtmosphericGradientView(
                                colorPalette: palette,
                                intensity: 1.0,
                                audioLevel: 0
                            )
                        } else {
                            Color.gray.opacity(0.2)
                        }

                        // Book cover overlay
                        bookCoverPreview(image: image, size: geo.size.width / 2 - 40)

                        // Debug info
                        if showDebugInfo, let palette = currentPalette {
                            currentDebugOverlay(palette: palette)
                        }
                    }

                    Text("\(String(format: "%.0f", currentExtractionTime))ms")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .background(Color.black)

                // Divider
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 2)

                // Intelligent system
                VStack(spacing: 0) {
                    Text("INTELLIGENT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.8))
                        .padding(.top, 8)

                    ZStack {
                        if let palette = intelligentPalette {
                            AtmosphericGradientRenderer(
                                palette: palette,
                                intensity: 1.0,
                                showDebugOverlay: false
                            )
                        } else if isExtracting {
                            Color.black
                                .overlay {
                                    VStack {
                                        ProgressView()
                                            .tint(.cyan)
                                        Text("Analyzing...")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                        } else {
                            Color.gray.opacity(0.2)
                        }

                        // Book cover overlay
                        bookCoverPreview(image: image, size: geo.size.width / 2 - 40)

                        // Debug info
                        if showDebugInfo, let palette = intelligentPalette {
                            intelligentDebugOverlay(palette: palette)
                        }
                    }

                    Text("\(String(format: "%.0f", intelligentExtractionTime))ms")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.cyan.opacity(0.6))
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
                .background(Color.black)
            }
        }
    }

    @State private var showIntelligent = false

    private func toggleView(book: BookModel, image: UIImage) -> some View {
        ZStack {
            if showIntelligent {
                if let palette = intelligentPalette {
                    AtmosphericGradientRenderer(
                        palette: palette,
                        intensity: 1.0,
                        showDebugOverlay: showDebugInfo
                    )
                }
            } else {
                if let palette = currentPalette {
                    BookAtmosphericGradientView(
                        colorPalette: palette,
                        intensity: 1.0,
                        audioLevel: 0
                    )
                }
            }

            // Book cover
            VStack {
                Spacer()
                    .frame(height: 100)
                bookCoverPreview(image: image, size: 180)
                Spacer()
            }

            // Toggle indicator
            VStack {
                HStack {
                    Text(showIntelligent ? "INTELLIGENT" : "CURRENT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(showIntelligent ? .cyan : .white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                        )
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                showIntelligent.toggle()
            }
        }
    }

    @State private var overlayOpacity: Double = 0.5

    private func overlayView(book: BookModel, image: UIImage) -> some View {
        ZStack {
            // Current as base
            if let palette = currentPalette {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 1.0,
                    audioLevel: 0
                )
            }

            // Intelligent as overlay
            if let palette = intelligentPalette {
                AtmosphericGradientRenderer(
                    palette: palette,
                    intensity: 1.0,
                    showDebugOverlay: false
                )
                .opacity(overlayOpacity)
            }

            // Book cover
            VStack {
                Spacer()
                    .frame(height: 100)
                bookCoverPreview(image: image, size: 180)
                Spacer()
            }

            // Opacity slider
            VStack {
                Spacer()
                HStack {
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                    Slider(value: $overlayOpacity, in: 0...1)
                        .tint(.cyan)
                    Text("Intelligent")
                        .font(.caption2)
                        .foregroundStyle(.cyan.opacity(0.8))
                }
                .padding(.horizontal)
                .padding(.bottom, 200)
            }
        }
    }

    private func bookCoverPreview(image: UIImage, size: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size * 0.6, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }

    private var noBookView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.2))

            Text("Select a book to compare")
                .foregroundStyle(.white.opacity(0.5))

            Button {
                showBookPicker = true
            } label: {
                Text("Choose Book")
                    .foregroundStyle(.cyan)
            }
        }
    }

    // MARK: - Debug Overlays

    private func currentDebugOverlay(palette: ColorPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ColorCube Extraction")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 3) {
                colorSwatch(palette.primary, label: "P")
                colorSwatch(palette.secondary, label: "S")
                colorSwatch(palette.accent, label: "A")
                colorSwatch(palette.background, label: "B")
            }

            Text("Quality: \(String(format: "%.0f", palette.extractionQuality * 100))%")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.6)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(8)
    }

    private func intelligentDebugOverlay(palette: IntelligentColorExtractor.IntelligentPalette) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Vision + Saliency")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.cyan.opacity(0.9))

            HStack(spacing: 3) {
                ForEach(palette.focalColors.prefix(4)) { color in
                    colorSwatch(color.color, label: "F")
                }
            }

            Text("Type: \(String(describing: palette.coverType))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            Text("Conf: \(String(format: "%.0f", palette.confidence * 100))%")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(palette.confidence > 0.7 ? .green.opacity(0.8) : .orange.opacity(0.8))

            Text("Text: \(String(format: "%.0f", palette.debugInfo.textRegionsCoverage * 100))% excluded")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.6)))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(8)
    }

    private func colorSwatch(_ color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            Text(label)
                .font(.system(size: 7, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Controls

    private var controlsPanel: some View {
        VStack(spacing: 12) {
            // Book info
            if let book = targetBook {
                VStack(spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(book.author)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            // Mode picker
            Picker("Mode", selection: $comparisonMode) {
                ForEach(ComparisonMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Options
            HStack {
                Toggle("Debug Info", isOn: $showDebugInfo)
                    .font(.system(size: 13))
                    .tint(.cyan)

                Spacer()

                Button {
                    Task { await extractBothSystems() }
                } label: {
                    Label("Re-extract", systemImage: "arrow.clockwise")
                        .font(.system(size: 13))
                }
                .disabled(isExtracting)
            }
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }

    // MARK: - Book Picker

    private var bookPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(booksWithCovers, id: \.localId) { book in
                            Button {
                                selectedBook = book
                                showBookPicker = false
                            } label: {
                                HStack(spacing: 16) {
                                    if let data = book.coverImageData,
                                       let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 50, height: 75)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(book.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                        Text(book.author)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.6))
                                    }

                                    Spacer()

                                    if selectedBook?.localId == book.localId {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.cyan)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedBook?.localId == book.localId
                                              ? Color.cyan.opacity(0.15)
                                              : Color.white.opacity(0.05))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showBookPicker = false
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Extraction

    private func extractBothSystems() async {
        guard let image = bookImage else { return }

        isExtracting = true

        // Extract with current system
        let currentStart = CFAbsoluteTimeGetCurrent()
        let currentExtractor = OKLABColorExtractor()
        if let palette = try? await currentExtractor.extractPalette(from: image, imageSource: targetBook?.title ?? "test") {
            await MainActor.run {
                currentPalette = palette
                currentExtractionTime = (CFAbsoluteTimeGetCurrent() - currentStart) * 1000
            }
        }

        // Extract with intelligent system
        let intelligentStart = CFAbsoluteTimeGetCurrent()
        let intelligentExtractor = IntelligentColorExtractor()
        if let palette = try? await intelligentExtractor.extractPalette(from: image, bookTitle: targetBook?.title ?? "test") {
            await MainActor.run {
                intelligentPalette = palette
                intelligentExtractionTime = (CFAbsoluteTimeGetCurrent() - intelligentStart) * 1000
            }
        }

        await MainActor.run {
            isExtracting = false
        }
    }
}

#Preview {
    GradientComparisonLab()
        .modelContainer(for: BookModel.self)
}
