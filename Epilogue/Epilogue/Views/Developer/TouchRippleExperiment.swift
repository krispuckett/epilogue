import SwiftUI
import SwiftData
import Combine

/// Touch-interactive liquid glass shader experiment
/// Touch and hold on the gradient to create liquid glass waves
/// Access from Settings > Developer Options
struct TouchRippleExperiment: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // Shader parameters
    @State private var waveSpeed: CGFloat = 1.0
    @State private var displacementAmount: CGFloat = 35.0
    @State private var refractionStrength: CGFloat = 0.5
    @State private var noiseScale: CGFloat = 3.0
    @State private var blurRadius: CGFloat = 30.0

    // ULTRA parameters
    @State private var chromaticAberration: CGFloat = 0.0
    @State private var vortexStrength: CGFloat = 0.0
    @State private var waveRingCount: CGFloat = 3.0
    @State private var turbulence: CGFloat = 0.0

    // UI state
    @State private var showControls: Bool = true
    @State private var showBookPicker: Bool = false
    @State private var selectedBook: BookModel?
    @State private var effectMode: EffectMode = .ultra

    enum EffectMode: String, CaseIterable {
        case liquidGlass = "Basic"
        case ultra = "ULTRA"
        case ambient = "Ambient"
    }

    // Books with covers only
    private var booksWithCovers: [BookModel] {
        books.filter { $0.coverImageData != nil }
    }

    // Find Lord of the Rings or fall back to first book
    private var targetBook: BookModel? {
        if let selected = selectedBook {
            return selected
        }
        // Try to find Lord of the Rings
        if let lotr = booksWithCovers.first(where: {
            $0.title.localizedCaseInsensitiveContains("Lord of the Rings") ||
            $0.title.localizedCaseInsensitiveContains("Fellowship")
        }) {
            return lotr
        }
        return booksWithCovers.first
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
                Color.black
                    .ignoresSafeArea()

                if let book = targetBook {
                    rippleGradientView(book: book)
                } else {
                    Text("No books with covers found")
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

                // Tap hint
                VStack {
                    Text(effectMode == .ambient ? "Ambient flow active" : "Touch & hold for liquid glass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 100)
                    Spacer()
                }
                .allowsHitTesting(false)
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

                ToolbarItem(placement: .principal) {
                    Text("Liquid Glass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showBookPicker = true
                        } label: {
                            Image(systemName: "book.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }

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

    // MARK: - Liquid Glass Gradient View
    @ViewBuilder
    private func rippleGradientView(book: BookModel) -> some View {
        ZStack {
            if let image = bookCoverImage {
                // Full-screen atmospheric gradient with liquid glass effect
                LiquidGlassAtmosphericGradient(
                    image: image,
                    blurRadius: blurRadius,
                    effectMode: effectMode,
                    waveSpeed: waveSpeed,
                    displacementAmount: displacementAmount,
                    refractionStrength: refractionStrength,
                    noiseScale: noiseScale,
                    chromaticAberration: chromaticAberration,
                    vortexStrength: vortexStrength,
                    waveRingCount: waveRingCount,
                    turbulence: turbulence
                )
                .ignoresSafeArea()
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: [.red, .orange, .purple, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blur(radius: blurRadius)
                .liquidGlassWave(
                    waveSpeed: waveSpeed,
                    displacementAmount: displacementAmount,
                    refractionStrength: refractionStrength,
                    noiseScale: noiseScale
                )
                .ignoresSafeArea()
            }

            // Book info at bottom
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Text(book.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(book.author)
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, showControls ? 320 : 60)
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Controls Panel
    private var controlsPanel: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Effect Mode Picker
                Picker("Mode", selection: $effectMode) {
                    ForEach(EffectMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Divider().background(Color.white.opacity(0.2))

                // Wave Speed
                parameterSlider(title: "Wave Speed", value: $waveSpeed, range: 0.2...3.0, format: "%.2f")

                // Displacement
                parameterSlider(title: "Displacement", value: $displacementAmount, range: 5...100, format: "%.0f px")

                // Refraction
                parameterSlider(title: "Refraction", value: $refractionStrength, range: 0...1.0, format: "%.2f")

                // Noise Scale
                parameterSlider(title: "Noise Scale", value: $noiseScale, range: 1...10, format: "%.1f")

                // Show ULTRA controls only in ULTRA mode
                if effectMode == .ultra {
                    Divider().background(Color.white.opacity(0.2))

                    Text("ULTRA PARAMETERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Chromatic Aberration
                    parameterSlider(title: "Chromatic", value: $chromaticAberration, range: 0...1.0, format: "%.2f", tint: .red)

                    // Vortex
                    parameterSlider(title: "Vortex", value: $vortexStrength, range: 0...1.0, format: "%.2f", tint: .purple)

                    // Wave Rings
                    parameterSlider(title: "Wave Rings", value: $waveRingCount, range: 1...10, format: "%.0f", tint: .cyan)

                    // Turbulence
                    parameterSlider(title: "Turbulence", value: $turbulence, range: 0...1.0, format: "%.2f", tint: .orange)
                }

                Divider().background(Color.white.opacity(0.2))

                // Blur Radius
                parameterSlider(title: "Blur Radius", value: $blurRadius, range: 0...80, format: "%.0f")
            }
            .padding(16)
        }
        .frame(maxHeight: 380)
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

    // MARK: - Parameter Slider Helper
    private func parameterSlider(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        format: String,
        tint: Color = .white
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint.opacity(0.9))
            }
            Slider(value: value, in: range)
                .tint(tint.opacity(0.8))
        }
    }
}

// MARK: - Liquid Glass Atmospheric Gradient
private struct LiquidGlassAtmosphericGradient: View {
    let image: UIImage
    let blurRadius: CGFloat
    let effectMode: TouchRippleExperiment.EffectMode
    let waveSpeed: CGFloat
    let displacementAmount: CGFloat
    let refractionStrength: CGFloat
    let noiseScale: CGFloat
    // ULTRA params
    let chromaticAberration: CGFloat
    let vortexStrength: CGFloat
    let waveRingCount: CGFloat
    let turbulence: CGFloat

    @State private var colorPalette: ColorPalette?

    var body: some View {
        Group {
            if let palette = colorPalette {
                gradientWithEffect(palette: palette)
            } else {
                Color.black
            }
        }
        .task {
            let extractor = OKLABColorExtractor()
            if let palette = try? await extractor.extractPalette(from: image, imageSource: "liquid-glass-experiment") {
                colorPalette = palette
            }
        }
    }

    @ViewBuilder
    private func gradientWithEffect(palette: ColorPalette) -> some View {
        switch effectMode {
        case .liquidGlass:
            BookAtmosphericGradientView(
                colorPalette: palette,
                intensity: 1.0,
                audioLevel: 0
            )
            .blur(radius: blurRadius)
            .liquidGlassWave(
                waveSpeed: waveSpeed,
                displacementAmount: displacementAmount,
                refractionStrength: refractionStrength,
                noiseScale: noiseScale
            )

        case .ultra:
            BookAtmosphericGradientView(
                colorPalette: palette,
                intensity: 1.0,
                audioLevel: 0
            )
            .blur(radius: blurRadius)
            .liquidGlassWaveUltra(
                waveSpeed: waveSpeed,
                displacementAmount: displacementAmount,
                refractionStrength: refractionStrength,
                noiseScale: noiseScale,
                chromaticAberration: chromaticAberration,
                vortexStrength: vortexStrength,
                waveRingCount: waveRingCount,
                turbulence: turbulence
            )

        case .ambient:
            BookAtmosphericGradientView(
                colorPalette: palette,
                intensity: 1.0,
                audioLevel: 0
            )
            .blur(radius: blurRadius)
            .ambientLiquidGlass(
                flowSpeed: waveSpeed,
                displacementAmount: displacementAmount * 0.5,
                refractionStrength: refractionStrength * 0.7,
                noiseScale: noiseScale
            )
        }
    }
}

#Preview {
    TouchRippleExperiment()
        .modelContainer(for: BookModel.self)
}
