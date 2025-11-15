import SwiftUI
import SwiftData
import Combine

/// Experimental shader effect for book covers
/// Applies a specular lens shader on top of atmospheric gradients
/// Access from Settings > Developer Options
struct SpecularLensExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // Shader animation state
    @State private var dragPosition: CGPoint = .zero
    @State private var isTouching: Bool = false
    @State private var rippleScale: CGFloat = 0

    // Adjustable parameters
    @State private var intensity: CGFloat = 3.0
    @State private var shaderEnabled: Bool = true
    @State private var showControls: Bool = true
    @State private var showBookPicker: Bool = false
    @State private var selectedBook: BookModel?

    // Toggle between auto-animate and touch modes
    @State private var touchMode: Bool = true

    // Books with covers only
    private var booksWithCovers: [BookModel] {
        books.filter { $0.coverImageData != nil }
    }

    // Currently selected book
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
                // Black background
                Color.black
                    .ignoresSafeArea()

                if let book = targetBook {
                    // Book cover with atmospheric gradient and shader
                    bookCoverWithShader(book: book)
                } else {
                    // No books found
                    Text("No books found in library")
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Controls overlay
                if showControls {
                    VStack {
                        Spacer()
                        controlsPanel
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // Book picker button
                        Button {
                            showBookPicker = true
                        } label: {
                            Image(systemName: "book.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }

                        // Controls visibility toggle
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showControls.toggle()
                            }
                        } label: {
                            Image(systemName: showControls ? "eye.slash" : "eye")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .sheet(isPresented: $showBookPicker) {
                ExperimentBookPickerSheet(
                    books: booksWithCovers,
                    selectedBook: $selectedBook
                )
            }
        }
    }

    // MARK: - Book Cover with Shader
    @ViewBuilder
    private func bookCoverWithShader(book: BookModel) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Atmospheric gradient background with shader effect
                ZStack {
                    if let image = bookCoverImage {
                        BookAtmosphericGradientWithImage(image: image)
                            .ignoresSafeArea()
                    } else {
                        // Fallback gradient if no cover image - BRIGHT and VISIBLE
                        LinearGradient(
                            stops: [
                                .init(color: Color.red.opacity(0.6), location: 0.0),
                                .init(color: Color.orange.opacity(0.5), location: 0.3),
                                .init(color: Color.purple.opacity(0.4), location: 0.6),
                                .init(color: Color.black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .ignoresSafeArea()
                    }
                }
                .modifier(
                    ConditionalShaderModifier(
                        enabled: shaderEnabled && (!touchMode || isTouching),
                        dragPosition: dragPosition,
                        intensity: intensity
                    )
                )
                .overlay {
                    // Touch ripple effect
                    if isTouching && touchMode {
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                            .frame(width: 60, height: 60)
                            .scaleEffect(rippleScale)
                            .opacity(1.0 - rippleScale)
                            .position(dragPosition)
                            .allowsHitTesting(false)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isTouching {
                                // First touch - trigger ripple
                                isTouching = true
                                rippleScale = 0
                                withAnimation(.easeOut(duration: 0.6)) {
                                    rippleScale = 3.0
                                }
                            }
                            dragPosition = value.location
                        }
                        .onEnded { _ in
                            isTouching = false
                            rippleScale = 0
                        }
                )

                // Book cover in center - NO SHADER, just the cover
                if let image = bookCoverImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 240, height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
                        .allowsHitTesting(false)
                } else {
                    // Placeholder when no cover image - BRIGHT and VISIBLE
                    ZStack {
                        // Bright placeholder card
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 240, height: 360)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                            }

                        // Icon and text
                        VStack(spacing: 16) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(.white.opacity(0.6))

                            Text("No Cover Image")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))

                            Text("Touch gradient to see shader")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .frame(width: 240, height: 360)
                    .shadow(color: .black.opacity(0.5), radius: 40, x: 0, y: 20)
                    .allowsHitTesting(false)
                }

                // Debug info overlay (top center)
                VStack {
                    Text(bookCoverImage == nil ? "⚠️ No cover image data" : "✅ Cover loaded")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(bookCoverImage == nil ? .red : .green)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 100)

                    Spacer()
                }

                // Book info overlay
                VStack {
                    Spacer()

                    VStack(spacing: 8) {
                        Text(book.title)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))

                        Text(book.author)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.top, 480)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // Touch mode toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Touch Mode")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(touchMode ? "Tap & drag to reveal" : "Always visible")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Toggle("", isOn: $touchMode)
                    .labelsHidden()
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Enable/Disable shader
            HStack {
                Text("Shader Effect")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                Toggle("", isOn: $shaderEnabled)
                    .labelsHidden()
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Intensity slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Intensity")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.1f", intensity))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Slider(value: $intensity, in: 0...10)
                    .tint(.white.opacity(0.8))
            }

            // Touch status
            if touchMode {
                HStack {
                    Image(systemName: isTouching ? "hand.point.up.left.fill" : "hand.point.up.left")
                        .font(.system(size: 14))
                        .foregroundStyle(isTouching ? .green : .white.opacity(0.5))

                    Text(isTouching ? "Touching" : "Not touching")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isTouching ? .green : .white.opacity(0.7))

                    Spacer()

                    if isTouching {
                        Text("(\(Int(dragPosition.x)), \(Int(dragPosition.y)))")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Conditional Shader Modifier
struct ConditionalShaderModifier: ViewModifier {
    let enabled: Bool
    let dragPosition: CGPoint
    let intensity: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            content
                .layerEffect(
                    ShaderLibrary.specular_position_lens(
                        .boundingRect,
                        .float2(dragPosition),
                        .float(intensity)
                    ),
                    maxSampleOffset: CGSize(width: 400, height: 400)
                )
        } else {
            content
        }
    }
}

// MARK: - Atmospheric Gradient Helper
struct BookAtmosphericGradientWithImage: View {
    let image: UIImage
    @State private var colorPalette: ColorPalette?

    var body: some View {
        Group {
            if let palette = colorPalette {
                BookAtmosphericGradientView(
                    colorPalette: palette,
                    intensity: 1.0,
                    audioLevel: 0
                )
            } else {
                Color.black
            }
        }
        .task {
            // Extract colors asynchronously
            let extractor = OKLABColorExtractor()
            if let palette = try? await extractor.extractPalette(from: image, imageSource: "experiment") {
                colorPalette = palette
            }
        }
    }
}

// MARK: - Experiment Book Picker Sheet
struct ExperimentBookPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let books: [BookModel]
    @Binding var selectedBook: BookModel?

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                if books.isEmpty {
                    // No books with covers
                    VStack(spacing: 16) {
                        Image(systemName: "book.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.3))

                        Text("No books with covers found")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Add books to your library first")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                } else {
                    // Book list
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(books, id: \.localId) { book in
                                Button {
                                    selectedBook = book
                                    dismiss()
                                    SensoryFeedback.selection()
                                } label: {
                                    HStack(spacing: 16) {
                                        // Cover thumbnail
                                        if let imageData = book.coverImageData,
                                           let image = UIImage(data: imageData) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 50, height: 75)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                        } else {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color.white.opacity(0.1))
                                                .frame(width: 50, height: 75)
                                                .overlay {
                                                    Image(systemName: "book")
                                                        .foregroundStyle(.white.opacity(0.3))
                                                }
                                        }

                                        // Book info
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(book.title)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.9))
                                                .lineLimit(2)

                                            Text(book.author)
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundStyle(.white.opacity(0.6))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        // Selection indicator
                                        if selectedBook?.localId == book.localId {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                selectedBook?.localId == book.localId
                                                    ? Color.white.opacity(0.15)
                                                    : Color.white.opacity(0.05)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                    }
                }
            }
            .navigationTitle("Choose Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SpecularLensExperiment()
        .modelContainer(for: BookModel.self)
}
