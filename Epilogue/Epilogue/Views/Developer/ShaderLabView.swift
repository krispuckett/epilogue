import SwiftUI
import SwiftData

struct ShaderLabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [BookModel]

    // Which effect is active
    @State private var activeEffect: ShaderEffect = .liveRipple

    // Shared
    @State private var showControls = true
    @State private var showBookPicker = false
    @State private var selectedBook: BookModel?
    @State private var coverImage: UIImage?
    @State private var startTime = Date.now

    // Touch tracking
    @State private var touchLocation: CGPoint = CGPoint(x: 180, y: 280)
    @State private var touchTime: Date = .distantPast

    // Emboss
    @State private var embossStrength: Float = 2.0
    @State private var embossAngle: Float = 0.785
    @State private var embossMix: Float = 0.8

    // Holographic
    @State private var holoIntensity: Float = 0.4
    @State private var holoScale: Float = 8.0
    @State private var holoSpeed: Float = 1.0
    @State private var holoAngle: Float = 0.785

    // Ink Bleed
    @State private var inkWarpStrength: Float = 15.0
    @State private var inkScale: Float = 4.0
    @State private var inkSpeed: Float = 0.5
    @State private var inkDetail: Float = 5.0

    // Chromatic Split
    @State private var chromaSpread: Float = 8.0
    @State private var chromaAngle: Float = 0.0
    @State private var chromaEdgeOnly: Float = 0.5
    @State private var chromaAnimate: Float = 0.5

    // Live Ripple
    @State private var rippleAmplitude: Float = 12.0
    @State private var rippleFrequency: Float = 25.0
    @State private var rippleSpeed: Float = 4.0
    @State private var rippleDamping: Float = 2.0
    @State private var rippleRingCount: Float = 3.0

    // Touch Ripple
    @State private var touchRippleAmplitude: Float = 15.0
    @State private var touchRippleFrequency: Float = 20.0
    @State private var touchRippleSpeed: Float = 300.0
    @State private var touchRippleDecay: Float = 2.0

    // Glitch
    @State private var glitchIntensity: Float = 0.5
    @State private var glitchBlockSize: Float = 15.0
    @State private var glitchScanLines: Float = 0.4
    @State private var glitchColorShift: Float = 8.0

    // Vortex
    @State private var vortexTwist: Float = 3.0
    @State private var vortexRadius: Float = 0.5
    @State private var vortexSpeed: Float = 0.5
    @State private var vortexFalloff: Float = 2.0

    // Pulse
    @State private var pulseAmplitude: Float = 15.0
    @State private var pulseBPM: Float = 72.0
    @State private var pulseSharpness: Float = 3.0
    @State private var pulseGlow: Float = 0.5
    @State private var pulseDistortion: Float = 12.0

    // Luminous Pool
    @State private var poolGlowHeight: Float = 0.3
    @State private var poolGlowIntensity: Float = 1.0
    @State private var poolDistortion: Float = 25.0
    @State private var poolWarpScale: Float = 3.0
    @State private var poolSpeed: Float = 1.0
    @State private var poolColorShift: Float = 0.2

    // Ethereal Aura
    @State private var auraWidth: Float = 0.12
    @State private var auraIntensity: Float = 1.0
    @State private var auraPulseSpeed: Float = 1.5
    @State private var auraDistortion: Float = 8.0
    @State private var auraHueShift: Float = 3.5

    // Melt
    @State private var meltAmount: Float = 40.0
    @State private var meltDripScale: Float = 6.0
    @State private var meltSpeed: Float = 1.0
    @State private var meltHeat: Float = 0.3

    // Refract Lens (interactive)
    @State private var lensRadius: Float = 0.3
    @State private var lensRefraction: Float = 2.0
    @State private var lensAberration: Float = 5.0
    @State private var lensWobble: Float = 0.5

    // Echo
    @State private var echoCount: Float = 4.0
    @State private var echoSpread: Float = 20.0
    @State private var echoDirection: Float = 0.785
    @State private var echoFade: Float = 0.6

    // Neon Edge
    @State private var neonEdgeStrength: Float = 4.0
    @State private var neonGlowAmount: Float = 1.0
    @State private var neonColorCycle: Float = 1.0
    @State private var neonMixOriginal: Float = 0.3
    @State private var neonSpeed: Float = 1.0

    // Shockwave
    @State private var shockwaveSpeed: Float = 200.0
    @State private var shockwaveRingWidth: Float = 30.0
    @State private var shockwaveStrength: Float = 40.0
    @State private var shockwaveRepeat: Float = 2.0

    // Thermal
    @State private var thermalIntensity: Float = 0.8
    @State private var thermalShimmer: Float = 5.0
    @State private var thermalNoiseSpeed: Float = 1.5
    @State private var thermalPaletteShift: Float = 0.0

    // Gravity Wells
    @State private var gravityStrength: Float = 80.0
    @State private var gravityWellCount: Float = 3.0
    @State private var gravityOrbitSpeed: Float = 0.8
    @State private var gravityFalloff: Float = 2.0

    // Crystal Prism
    @State private var crystalFacetSize: Float = 8.0
    @State private var crystalDispersion: Float = 15.0
    @State private var crystalRotation: Float = 0.5
    @State private var crystalSparkle: Float = 0.3

    // Liquid Mirror
    @State private var mirrorAxis: Float = 0.55
    @State private var mirrorRipple: Float = 12.0
    @State private var mirrorSpeed: Float = 1.5
    @State private var mirrorDepth: Float = 0.5

    // Disintegrate
    @State private var disintegrateThreshold: Float = 0.0
    @State private var disintegrateEdge: Float = 0.12
    @State private var disintegrateDrift: Float = 25.0
    @State private var disintegrateDirection: Float = 1.0

    // Solarize
    @State private var solarizeThreshold: Float = 0.5
    @State private var solarizeCurve: Float = 1.5
    @State private var solarizeColorSep: Float = 0.5
    @State private var solarizeAnimate: Float = 0.5

    // Pixelate Mosaic
    @State private var mosaicPixelSize: Float = 20.0
    @State private var mosaicBevel: Float = 0.6
    @State private var mosaicAssemble: Float = 0.5
    @State private var mosaicGap: Float = 0.05

    // Datamosh
    @State private var datamoshCorruption: Float = 0.4
    @State private var datamoshSmear: Float = 30.0
    @State private var datamoshColorBleed: Float = 0.5
    @State private var datamoshRate: Float = 2.0

    // Magnetic Field
    @State private var magnetStrength: Float = 40.0
    @State private var magnetLines: Float = 8.0
    @State private var magnetTurbulence: Float = 0.5
    @State private var magnetPolarity: Float = 0.0

    // Underwater Caustics
    @State private var causticScale: Float = 6.0
    @State private var causticIntensity: Float = 1.0
    @State private var causticDistortion: Float = 12.0
    @State private var causticDepth: Float = 0.4

    // Topographic
    @State private var topoLines: Float = 20.0
    @State private var topoLineWidth: Float = 0.05
    @State private var topoColorize: Float = 0.7
    @State private var topoAnimate: Float = 0.3

    // Smoke Reveal
    @State private var smokeAmount: Float = 0.6
    @State private var smokeScale: Float = 5.0
    @State private var smokeWind: Float = 1.5
    @State private var smokeTurbulence: Float = 1.5

    // X-Ray
    @State private var xrayIntensity: Float = 0.8
    @State private var xrayEdge: Float = 3.0
    @State private var xrayScanLine: Float = 0.5
    @State private var xrayContrast: Float = 1.5

    // Geometric Warp
    @State private var geoSpiral: Float = 3.0
    @State private var geoZoom: Float = 1.0
    @State private var geoRotation: Float = 0.0
    @State private var geoBlend: Float = 0.0

    // Noir Sketch
    @State private var noirLineWeight: Float = 1.5
    @State private var noirCrossHatch: Float = 0.6
    @State private var noirPaper: Float = 0.3
    @State private var noirInk: Float = 0.7

    // Shatter Glass
    @State private var shatterDensity: Float = 8.0
    @State private var shatterRefraction: Float = 10.0
    @State private var shatterPrism: Float = 0.5
    @State private var shatterSpread: Float = 0.0

    enum ShaderEffect: String, CaseIterable {
        case luminousPool = "Pool"
        case etherealAura = "Aura"
        case shockwave = "Shock"
        case gravityWells = "Gravity"
        case crystalPrism = "Crystal"
        case refractLens = "Lens"
        case liquidMirror = "Mirror"
        case neonEdge = "Neon"
        case thermal = "Thermal"
        case liveRipple = "Ripple"
        case touchRipple = "Touch"
        case vortex = "Vortex"
        case melt = "Melt"
        case pulse = "Pulse"
        case glitch = "Glitch"
        case echo = "Echo"
        case holographic = "Holo"
        case emboss = "Emboss"
        case inkBleed = "Ink"
        case chromaticSplit = "Chroma"
        case disintegrate = "Dust"
        case solarize = "Solar"
        case pixelateMosaic = "Mosaic"
        case datamosh = "Datamosh"
        case magneticField = "Magnetic"
        case underwaterCaustics = "Caustics"
        case topographic = "Topo"
        case smokeReveal = "Smoke"
        case xray = "X-Ray"
        case geometricWarp = "Droste"
        case noirSketch = "Noir"
        case shatterGlass = "Shatter"
    }

    private var booksWithCovers: [BookModel] {
        books.filter { $0.coverImageData != nil }
    }

    private var targetBook: BookModel? {
        if let selected = selectedBook { return selected }
        if let lotr = booksWithCovers.first(where: {
            $0.title.localizedCaseInsensitiveContains("Lord of the Rings") ||
            $0.title.localizedCaseInsensitiveContains("Fellowship")
        }) {
            return lotr
        }
        return booksWithCovers.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let book = targetBook {
                    coverWithShader(book: book)
                } else {
                    Text("No books with covers found")
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Controls
                if showControls {
                    VStack(spacing: 0) {
                        Spacer()
                        controlsPanel
                            .padding(.bottom, 40)
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
                ToolbarItem(placement: .principal) {
                    Text("Shader Lab")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button { showBookPicker = true } label: {
                            Image(systemName: "book.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Button {
                            withAnimation(.spring(response: 0.3)) { showControls.toggle() }
                        } label: {
                            Image(systemName: showControls ? "slider.horizontal.below.square.filled.and.square" : "slider.horizontal.3")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .sheet(isPresented: $showBookPicker) {
                bookPicker
            }
        }
    }

    // MARK: - Cover with Shader

    private var isFullScreenEffect: Bool {
        activeEffect == .luminousPool || activeEffect == .etherealAura
    }

    @ViewBuilder
    private func coverWithShader(book: BookModel) -> some View {
        TimelineView(.animation) { timeline in
            let elapsed = Float(startTime.distance(to: timeline.date))

            if isFullScreenEffect {
                // Full-screen mode — no text overlay
                if let image = coverImage {
                    fullScreenShaderCover(image: image, time: elapsed)
                }
            } else {
                // Card mode
                VStack(spacing: 16) {
                    Spacer()

                    if let image = coverImage {
                        shaderCover(image: image, time: elapsed)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 280, height: 420)
                    }

                    VStack(spacing: 6) {
                        Text(book.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(book.author)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                    if showControls { Spacer().frame(height: 300) }
                }
            }
        }
        .task(id: targetBook?.id) {
            loadCoverImage()
        }
    }

    private func loadCoverImage() {
        guard let book = targetBook,
              let data = book.coverImageData,
              let image = UIImage(data: data) else {
            coverImage = nil
            return
        }
        coverImage = image
    }

    // MARK: - Full Screen Shader Cover

    @ViewBuilder
    private func fullScreenShaderCover(image: UIImage, time: Float) -> some View {
        let base = GeometryReader { geo in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .drawingGroup()

        Group {
            switch activeEffect {
            case .luminousPool:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_luminousPool(
                            .float2(proxy.size),
                            .float(time),
                            .float(poolGlowHeight),
                            .float(poolGlowIntensity),
                            .float(poolDistortion),
                            .float(poolWarpScale),
                            .float(poolSpeed),
                            .float(poolColorShift)
                        ),
                        maxSampleOffset: CGSize(width: 50, height: 50)
                    )
                }

            case .etherealAura:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_etherealAura(
                            .float2(proxy.size),
                            .float(time),
                            .float(auraWidth),
                            .float(auraIntensity),
                            .float(auraPulseSpeed),
                            .float(auraDistortion),
                            .float(auraHueShift)
                        ),
                        maxSampleOffset: CGSize(width: 25, height: 25)
                    )
                }

            default:
                base
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Shader Cover (Card Mode)

    @ViewBuilder
    private func shaderCover(image: UIImage, time: Float) -> some View {
        let base = Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: 280, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(40)
            .drawingGroup()

        Group {
            switch activeEffect {
            case .emboss:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_emboss(
                            .float2(proxy.size),
                            .float(embossStrength),
                            .float(embossAngle),
                            .float(embossMix)
                        ),
                        maxSampleOffset: CGSize(width: 5, height: 5)
                    )
                }

            case .holographic:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_holographic(
                            .float2(proxy.size),
                            .float(time),
                            .float(holoIntensity),
                            .float(holoScale),
                            .float(holoSpeed),
                            .float(holoAngle)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .inkBleed:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_inkBleed(
                            .float2(proxy.size),
                            .float(time),
                            .float(inkWarpStrength),
                            .float(inkScale),
                            .float(inkSpeed),
                            .float(inkDetail)
                        ),
                        maxSampleOffset: CGSize(width: 60, height: 60)
                    )
                }

            case .chromaticSplit:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_chromaticSplit(
                            .float2(proxy.size),
                            .float(chromaSpread),
                            .float(chromaAngle),
                            .float(chromaEdgeOnly),
                            .float(time),
                            .float(chromaAnimate)
                        ),
                        maxSampleOffset: CGSize(width: 40, height: 40)
                    )
                }

            case .liveRipple:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_liveRipple(
                            .float2(proxy.size),
                            .float(time),
                            .float(rippleAmplitude),
                            .float(rippleFrequency),
                            .float(rippleSpeed),
                            .float(rippleDamping),
                            .float(rippleRingCount)
                        ),
                        maxSampleOffset: CGSize(width: 35, height: 35)
                    )
                }

            case .touchRipple:
                let touchAge = Float(touchTime.distance(to: .now))
                base
                    .visualEffect { content, proxy in
                        content.layerEffect(
                            ShaderLibrary.bcs_touchRipple(
                                .float2(proxy.size),
                                .float2(touchLocation),
                                .float(touchAge),
                                .float(touchRippleAmplitude),
                                .float(touchRippleFrequency),
                                .float(touchRippleSpeed),
                                .float(touchRippleDecay)
                            ),
                            maxSampleOffset: CGSize(width: 50, height: 50)
                        )
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                touchLocation = value.location
                                touchTime = .now
                            }
                    )

            case .glitch:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_glitch(
                            .float2(proxy.size),
                            .float(time),
                            .float(glitchIntensity),
                            .float(glitchBlockSize),
                            .float(glitchScanLines),
                            .float(glitchColorShift)
                        ),
                        maxSampleOffset: CGSize(width: 50, height: 50)
                    )
                }

            case .vortex:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_vortex(
                            .float2(proxy.size),
                            .float(time),
                            .float(vortexTwist),
                            .float(vortexRadius),
                            .float(vortexSpeed),
                            .float(vortexFalloff)
                        ),
                        maxSampleOffset: CGSize(width: 200, height: 200)
                    )
                }

            case .pulse:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_pulse(
                            .float2(proxy.size),
                            .float(time),
                            .float(pulseAmplitude),
                            .float(pulseBPM),
                            .float(pulseSharpness),
                            .float(pulseGlow)
                        ),
                        maxSampleOffset: CGSize(width: 35, height: 35)
                    )
                }

            case .melt:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_melt(
                            .float2(proxy.size),
                            .float(time),
                            .float(meltAmount),
                            .float(meltDripScale),
                            .float(meltSpeed),
                            .float(meltHeat)
                        ),
                        maxSampleOffset: CGSize(width: 10, height: 120)
                    )
                }

            case .refractLens:
                base
                    .visualEffect { content, proxy in
                        content.layerEffect(
                            ShaderLibrary.bcs_refractLens(
                                .float2(proxy.size),
                                .float2(touchLocation),
                                .float(lensRadius),
                                .float(lensRefraction),
                                .float(lensAberration),
                                .float(lensWobble)
                            ),
                            maxSampleOffset: CGSize(width: 80, height: 80)
                        )
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                touchLocation = value.location
                            }
                    )

            case .echo:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_echo(
                            .float2(proxy.size),
                            .float(time),
                            .float(echoCount),
                            .float(echoSpread),
                            .float(echoDirection),
                            .float(echoFade)
                        ),
                        maxSampleOffset: CGSize(width: 60, height: 60)
                    )
                }

            case .neonEdge:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_neonEdge(
                            .float2(proxy.size),
                            .float(time * neonSpeed),
                            .float(neonEdgeStrength),
                            .float(neonGlowAmount),
                            .float(neonColorCycle),
                            .float(neonMixOriginal)
                        ),
                        maxSampleOffset: CGSize(width: 2, height: 2)
                    )
                }

            case .shockwave:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_shockwave(
                            .float2(proxy.size),
                            .float(time),
                            .float(shockwaveSpeed),
                            .float(shockwaveRingWidth),
                            .float(shockwaveStrength),
                            .float(shockwaveRepeat)
                        ),
                        maxSampleOffset: CGSize(width: 100, height: 100)
                    )
                }

            case .thermal:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_thermal(
                            .float2(proxy.size),
                            .float(time),
                            .float(thermalIntensity),
                            .float(thermalShimmer),
                            .float(thermalNoiseSpeed),
                            .float(thermalPaletteShift)
                        ),
                        maxSampleOffset: CGSize(width: 20, height: 20)
                    )
                }

            case .gravityWells:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_gravityWells(
                            .float2(proxy.size),
                            .float(time),
                            .float(gravityStrength),
                            .float(gravityWellCount),
                            .float(gravityOrbitSpeed),
                            .float(gravityFalloff)
                        ),
                        maxSampleOffset: CGSize(width: 200, height: 200)
                    )
                }

            case .crystalPrism:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_crystalPrism(
                            .float2(proxy.size),
                            .float(time),
                            .float(crystalFacetSize),
                            .float(crystalDispersion),
                            .float(crystalRotation),
                            .float(crystalSparkle)
                        ),
                        maxSampleOffset: CGSize(width: 40, height: 40)
                    )
                }

            case .liquidMirror:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_liquidMirror(
                            .float2(proxy.size),
                            .float(time),
                            .float(mirrorAxis),
                            .float(mirrorRipple),
                            .float(mirrorSpeed),
                            .float(mirrorDepth)
                        ),
                        maxSampleOffset: CGSize(width: 40, height: 40)
                    )
                }

            case .disintegrate:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_disintegrate(
                            .float2(proxy.size),
                            .float(time),
                            .float(disintegrateThreshold),
                            .float(disintegrateEdge),
                            .float(disintegrateDrift),
                            .float(disintegrateDirection)
                        ),
                        maxSampleOffset: CGSize(width: 60, height: 60)
                    )
                }

            case .solarize:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_solarize(
                            .float2(proxy.size),
                            .float(time),
                            .float(solarizeThreshold),
                            .float(solarizeCurve),
                            .float(solarizeColorSep),
                            .float(solarizeAnimate)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .pixelateMosaic:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_pixelateMosaic(
                            .float2(proxy.size),
                            .float(time),
                            .float(mosaicPixelSize),
                            .float(mosaicBevel),
                            .float(mosaicAssemble),
                            .float(mosaicGap)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .datamosh:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_datamosh(
                            .float2(proxy.size),
                            .float(time),
                            .float(datamoshCorruption),
                            .float(datamoshSmear),
                            .float(datamoshColorBleed),
                            .float(datamoshRate)
                        ),
                        maxSampleOffset: CGSize(width: 80, height: 80)
                    )
                }

            case .magneticField:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_magneticField(
                            .float2(proxy.size),
                            .float(time),
                            .float(magnetStrength),
                            .float(magnetLines),
                            .float(magnetTurbulence),
                            .float(magnetPolarity)
                        ),
                        maxSampleOffset: CGSize(width: 100, height: 100)
                    )
                }

            case .underwaterCaustics:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_underwaterCaustics(
                            .float2(proxy.size),
                            .float(time),
                            .float(causticScale),
                            .float(causticIntensity),
                            .float(causticDistortion),
                            .float(causticDepth)
                        ),
                        maxSampleOffset: CGSize(width: 40, height: 40)
                    )
                }

            case .topographic:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_topographic(
                            .float2(proxy.size),
                            .float(time),
                            .float(topoLines),
                            .float(topoLineWidth),
                            .float(topoColorize),
                            .float(topoAnimate)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .smokeReveal:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_smokeReveal(
                            .float2(proxy.size),
                            .float(time),
                            .float(smokeAmount),
                            .float(smokeScale),
                            .float(smokeWind),
                            .float(smokeTurbulence)
                        ),
                        maxSampleOffset: CGSize(width: 15, height: 15)
                    )
                }

            case .xray:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_xray(
                            .float2(proxy.size),
                            .float(time),
                            .float(xrayIntensity),
                            .float(xrayEdge),
                            .float(xrayScanLine),
                            .float(xrayContrast)
                        ),
                        maxSampleOffset: CGSize(width: 2, height: 2)
                    )
                }

            case .geometricWarp:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_geometricWarp(
                            .float2(proxy.size),
                            .float(time),
                            .float(geoSpiral),
                            .float(geoZoom),
                            .float(geoRotation),
                            .float(geoBlend)
                        ),
                        maxSampleOffset: CGSize(width: 200, height: 200)
                    )
                }

            case .noirSketch:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_noirSketch(
                            .float2(proxy.size),
                            .float(time),
                            .float(noirLineWeight),
                            .float(noirCrossHatch),
                            .float(noirPaper),
                            .float(noirInk)
                        ),
                        maxSampleOffset: CGSize(width: 2, height: 2)
                    )
                }

            case .shatterGlass:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_shatterGlass(
                            .float2(proxy.size),
                            .float(time),
                            .float(shatterDensity),
                            .float(shatterRefraction),
                            .float(shatterPrism),
                            .float(shatterSpread)
                        ),
                        maxSampleOffset: CGSize(width: 80, height: 80)
                    )
                }

            case .luminousPool, .etherealAura:
                // Full-screen mode
                base
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
    }

    // MARK: - Controls

    private var controlsPanel: some View {
        VStack(spacing: 0) {
            // Effect picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ShaderEffect.allCases, id: \.self) { effect in
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                activeEffect = effect
                                startTime = .now
                            }
                        } label: {
                            Text(effect.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(activeEffect == effect ? .black : .white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background {
                                    if activeEffect == effect {
                                        Capsule().fill(.white)
                                    } else {
                                        Capsule().fill(.white.opacity(0.12))
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)

            // Hints for interactive effects
            if activeEffect == .touchRipple {
                Text("Tap the cover to create ripples")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.cyan.opacity(0.7))
                    .padding(.bottom, 6)
            } else if activeEffect == .refractLens {
                Text("Drag to move the lens")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.cyan.opacity(0.7))
                    .padding(.bottom, 6)
            }

            // Parameter sliders
            ScrollView {
                VStack(spacing: 10) {
                    switch activeEffect {
                    case .emboss:
                        slider("Strength", $embossStrength, 0...5)
                        slider("Light Angle", $embossAngle, 0...6.28)
                        slider("Mix", $embossMix, 0...1)

                    case .holographic:
                        slider("Intensity", $holoIntensity, 0...1)
                        slider("Scale", $holoScale, 1...20)
                        slider("Speed", $holoSpeed, 0.1...3)
                        slider("Angle", $holoAngle, 0...6.28)

                    case .inkBleed:
                        slider("Warp", $inkWarpStrength, 0...50)
                        slider("Scale", $inkScale, 1...10)
                        slider("Speed", $inkSpeed, 0.1...2)
                        slider("Detail", $inkDetail, 2...8)

                    case .chromaticSplit:
                        slider("Spread", $chromaSpread, 0...30)
                        slider("Angle", $chromaAngle, 0...6.28)
                        slider("Edge Only", $chromaEdgeOnly, 0...1)
                        slider("Animate", $chromaAnimate, 0...1)

                    case .liveRipple:
                        slider("Amplitude", $rippleAmplitude, 0...30)
                        slider("Frequency", $rippleFrequency, 5...60)
                        slider("Speed", $rippleSpeed, 1...10)
                        slider("Damping", $rippleDamping, 0.5...5)
                        slider("Ring Sources", $rippleRingCount, 1...5)

                    case .touchRipple:
                        slider("Amplitude", $touchRippleAmplitude, 0...30)
                        slider("Frequency", $touchRippleFrequency, 5...40)
                        slider("Speed", $touchRippleSpeed, 50...500)
                        slider("Decay", $touchRippleDecay, 0.5...4)

                    case .glitch:
                        slider("Intensity", $glitchIntensity, 0...1)
                        slider("Block Size", $glitchBlockSize, 2...50)
                        slider("Scan Lines", $glitchScanLines, 0...1)
                        slider("Color Shift", $glitchColorShift, 0...20)

                    case .vortex:
                        slider("Twist", $vortexTwist, 0...10)
                        slider("Radius", $vortexRadius, 0.1...1)
                        slider("Speed", $vortexSpeed, 0.1...3)
                        slider("Falloff", $vortexFalloff, 0.5...5)

                    case .pulse:
                        slider("Amplitude", $pulseAmplitude, 0...30)
                        slider("BPM", $pulseBPM, 30...180)
                        slider("Sharpness", $pulseSharpness, 1...10)
                        slider("Edge Glow", $pulseGlow, 0...1)
                        slider("Distortion", $pulseDistortion, 0...30)

                    case .melt:
                        slider("Melt Amount", $meltAmount, 0...100)
                        slider("Drip Scale", $meltDripScale, 1...15)
                        slider("Speed", $meltSpeed, 0.1...3)
                        slider("Heat Color", $meltHeat, 0...1)

                    case .refractLens:
                        slider("Lens Radius", $lensRadius, 0.1...0.5)
                        slider("Refraction", $lensRefraction, 1...3)
                        slider("Aberration", $lensAberration, 0...15)
                        slider("Wobble", $lensWobble, 0...1)

                    case .echo:
                        slider("Echo Count", $echoCount, 2...8)
                        slider("Spread", $echoSpread, 5...50)
                        slider("Direction", $echoDirection, 0...6.28)
                        slider("Fade", $echoFade, 0.3...0.9)

                    case .neonEdge:
                        slider("Edge Strength", $neonEdgeStrength, 1...10)
                        slider("Glow", $neonGlowAmount, 0...2)
                        slider("Color Cycle", $neonColorCycle, 0...3)
                        slider("Original Mix", $neonMixOriginal, 0...1)
                        slider("Speed", $neonSpeed, 0...3)

                    case .shockwave:
                        slider("Wave Speed", $shockwaveSpeed, 50...500)
                        slider("Ring Width", $shockwaveRingWidth, 5...60)
                        slider("Strength", $shockwaveStrength, 5...80)
                        slider("Repeat Rate", $shockwaveRepeat, 0.5...5)

                    case .thermal:
                        slider("Intensity", $thermalIntensity, 0...1)
                        slider("Shimmer", $thermalShimmer, 0...15)
                        slider("Noise Speed", $thermalNoiseSpeed, 0.5...3)
                        slider("Palette Shift", $thermalPaletteShift, 0...1)

                    case .gravityWells:
                        slider("Strength", $gravityStrength, 10...200)
                        slider("Well Count", $gravityWellCount, 1...5)
                        slider("Orbit Speed", $gravityOrbitSpeed, 0.1...3)
                        slider("Falloff", $gravityFalloff, 0.5...5)

                    case .crystalPrism:
                        slider("Facet Size", $crystalFacetSize, 2...20)
                        slider("Dispersion", $crystalDispersion, 2...30)
                        slider("Rotation", $crystalRotation, 0...3)
                        slider("Sparkle", $crystalSparkle, 0...2)

                    case .liquidMirror:
                        slider("Mirror Line", $mirrorAxis, 0.3...0.7)
                        slider("Ripple", $mirrorRipple, 2...30)
                        slider("Speed", $mirrorSpeed, 0.5...3)
                        slider("Depth", $mirrorDepth, 0...1)

                    case .luminousPool:
                        slider("Glow Height", $poolGlowHeight, 0.05...0.5)
                        slider("Glow Intensity", $poolGlowIntensity, 0...2)
                        slider("Distortion", $poolDistortion, 0...60)
                        slider("Warp Scale", $poolWarpScale, 1...10)
                        slider("Speed", $poolSpeed, 0.2...3)
                        slider("Color (Cool/Warm)", $poolColorShift, 0...1)

                    case .etherealAura:
                        slider("Aura Width", $auraWidth, 0.02...0.3)
                        slider("Intensity", $auraIntensity, 0...2)
                        slider("Pulse Speed", $auraPulseSpeed, 0...3)
                        slider("Distortion", $auraDistortion, 0...20)
                        slider("Hue Shift", $auraHueShift, 0...6.28)

                    case .disintegrate:
                        slider("Dissolve", $disintegrateThreshold, 0...1)
                        slider("Edge Width", $disintegrateEdge, 0.05...0.3)
                        slider("Drift", $disintegrateDrift, 0...50)
                        slider("Direction", $disintegrateDirection, 0...6.28)

                    case .solarize:
                        slider("Threshold", $solarizeThreshold, 0.2...0.8)
                        slider("Curve", $solarizeCurve, 0...3)
                        slider("Color Split", $solarizeColorSep, 0...1)
                        slider("Animate", $solarizeAnimate, 0...1)

                    case .pixelateMosaic:
                        slider("Tile Size", $mosaicPixelSize, 4...60)
                        slider("Bevel", $mosaicBevel, 0...1)
                        slider("Scatter", $mosaicAssemble, 0...1)
                        slider("Gap", $mosaicGap, 0...0.3)

                    case .datamosh:
                        slider("Corruption", $datamoshCorruption, 0...1)
                        slider("Smear", $datamoshSmear, 0...60)
                        slider("Color Bleed", $datamoshColorBleed, 0...1)
                        slider("Glitch Rate", $datamoshRate, 0.5...5)

                    case .magneticField:
                        slider("Strength", $magnetStrength, 5...80)
                        slider("Field Lines", $magnetLines, 3...20)
                        slider("Turbulence", $magnetTurbulence, 0...1)
                        slider("Polarity", $magnetPolarity, 0...1)

                    case .underwaterCaustics:
                        slider("Pattern Scale", $causticScale, 2...15)
                        slider("Brightness", $causticIntensity, 0...2)
                        slider("Distortion", $causticDistortion, 0...30)
                        slider("Depth", $causticDepth, 0...1)

                    case .topographic:
                        slider("Contour Lines", $topoLines, 5...40)
                        slider("Line Width", $topoLineWidth, 0.01...0.15)
                        slider("Colorize", $topoColorize, 0...1)
                        slider("Animate", $topoAnimate, 0...1)

                    case .smokeReveal:
                        slider("Smoke", $smokeAmount, 0...1)
                        slider("Scale", $smokeScale, 2...10)
                        slider("Wind", $smokeWind, 0.5...3)
                        slider("Turbulence", $smokeTurbulence, 0.5...3)

                    case .xray:
                        slider("Intensity", $xrayIntensity, 0...1)
                        slider("Edge Detail", $xrayEdge, 0...5)
                        slider("Scan Line", $xrayScanLine, 0...1)
                        slider("Contrast", $xrayContrast, 0.5...3)

                    case .geometricWarp:
                        slider("Spiral", $geoSpiral, 1...8)
                        slider("Zoom Repeat", $geoZoom, 0.3...2)
                        slider("Rotation", $geoRotation, 0...6.28)
                        slider("Kaleidoscope", $geoBlend, 0...1)

                    case .noirSketch:
                        slider("Line Weight", $noirLineWeight, 0.5...3)
                        slider("Cross Hatch", $noirCrossHatch, 0...1)
                        slider("Paper Tone", $noirPaper, 0...1)
                        slider("Ink", $noirInk, 0.3...1)

                    case .shatterGlass:
                        slider("Crack Density", $shatterDensity, 3...15)
                        slider("Refraction", $shatterRefraction, 0...20)
                        slider("Prism", $shatterPrism, 0...1)
                        slider("Spread", $shatterSpread, 0...1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 200)
        }
        .padding(.vertical, 12)
        .glassEffect(.regular.tint(.black.opacity(0.3)), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func slider(_ title: String, _ value: Binding<Float>, _ range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
            }
            Slider(value: value, in: range)
                .tint(.white.opacity(0.6))
        }
    }

    // MARK: - Book Picker

    private var bookPicker: some View {
        NavigationStack {
            List(booksWithCovers, id: \.id) { book in
                Button {
                    selectedBook = book
                    showBookPicker = false
                    coverImage = nil
                } label: {
                    HStack(spacing: 12) {
                        if let data = book.coverImageData, let img = UIImage(data: data) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(book.title)
                                .font(.system(size: 15, weight: .medium))
                            Text(book.author)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Book")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ShaderLabView()
        .modelContainer(for: BookModel.self)
}
