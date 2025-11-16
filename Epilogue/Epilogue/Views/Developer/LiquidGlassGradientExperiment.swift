import SwiftUI
import SwiftData
import Combine

/// Experimental liquid glass lens shader applied to atmospheric gradients
/// Pill-shaped element with auto-animated shader effect
/// Access from Settings > Developer Options
struct LiquidGlassGradientExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // Touch interaction state
    @State private var dragPosition: CGPoint = .zero
    @State private var phase: CGFloat = 0

    // Shader parameters
    @State private var intensity: CGFloat = 3.0
    @State private var radius: CGFloat = 20.0
    @State private var shaderEnabled: Bool = true
    @State private var showControls: Bool = true
    @State private var showBookPicker: Bool = false
    @State private var selectedBook: BookModel?

    // Auto-animation timer
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

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
                    // Atmospheric gradient with shader effect
                    gradientWithShader(book: book)
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
                ExperimentalBookPickerSheet(
                    books: booksWithCovers,
                    selectedBook: $selectedBook
                )
            }
        }
    }

    // MARK: - Gradient with Shader
    @ViewBuilder
    private func gradientWithShader(book: BookModel) -> some View {
        VStack(spacing: 20) {
            // Pill-shaped gradient with shader - exactly like the button code
            ZStack {
                if let image = bookCoverImage {
                    // Blurred atmospheric gradient
                    BookAtmosphericGradientWithImage(image: image)
                        .blur(radius: radius)
                        .frame(width: 320, height: 320)
                        .layerEffect(
                            ShaderLibrary.specular_position_lens(
                                .boundingRect,
                                .float2(dragPosition),
                                .float(intensity)
                            ),
                            maxSampleOffset: CGSize(width: 400, height: 400)
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragPosition = value.location
                                }
                        )
                } else {
                    // Fallback gradient
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
                    .blur(radius: radius)
                    .frame(width: 320, height: 320)
                    .layerEffect(
                        ShaderLibrary.specular_position_lens(
                            .boundingRect,
                            .float2(dragPosition),
                            .float(intensity)
                        ),
                        maxSampleOffset: CGSize(width: 400, height: 400)
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragPosition = value.location
                            }
                    )
                }
            }
            .frame(width: 160, height: 40)
            .cornerRadius(20)
            .onReceive(timer) { _ in
                phase += 0.01
                dragPosition.x = 160 + sin(phase) * 240
                dragPosition.y = 160 + cos(phase) * 240
            }
            .padding(.top, 100)

            // Phase debug
            Text("phase: \(tan(phase), specifier: "%.2f")")
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .monospaced()
                .bold()
                .padding()
                .frame(width: 160)
                .glassEffect(.clear.tint(.black.opacity(0.1)))

            // Book info
            VStack(spacing: 8) {
                Text(book.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))

                Text(book.author)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        VStack(spacing: 16) {
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

            Divider()
                .background(Color.white.opacity(0.2))

            // Blur radius slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Blur Radius")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.1f", radius))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Slider(value: $radius, in: 0...40)
                    .tint(.white.opacity(0.8))
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

// MARK: - Experimental Book Picker Sheet
struct ExperimentalBookPickerSheet: View {
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
    LiquidGlassGradientExperiment()
        .modelContainer(for: BookModel.self)
}
