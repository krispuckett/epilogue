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

    // --- Atmospheric Background Generators ---

    // Mesh Gradient
    @State private var meshWarp: Float = 0.5
    @State private var meshSmoothness: Float = 2.0
    @State private var meshSpeed: Float = 1.0
    @State private var meshSatBoost: Float = 0.4

    // Dream Blur
    @State private var dreamBlurRadius: Float = 60.0
    @State private var dreamWarpStrength: Float = 0.5
    @State private var dreamBreatheSpeed: Float = 1.0
    @State private var dreamSatBoost: Float = 0.4

    // Liquid Bloom
    @State private var bloomRadius: Float = 0.4
    @State private var bloomTurbulence: Float = 0.5
    @State private var bloomFlowSpeed: Float = 1.0
    @State private var bloomColorIntensity: Float = 1.2

    // Heat Mirage
    @State private var mirageDistortion: Float = 25.0
    @State private var mirageWaveScale: Float = 6.0
    @State private var mirageRiseSpeed: Float = 1.5
    @State private var mirageBlur: Float = 0.4

    // Radial Smear
    @State private var smearLength: Float = 0.2
    @State private var smearRotation: Float = 0.3
    @State private var smearPulseSpeed: Float = 1.0
    @State private var smearClarity: Float = 0.2

    // Chromatic Fog
    @State private var fogDensity: Float = 50.0
    @State private var fogSeparation: Float = 15.0
    @State private var fogDriftSpeed: Float = 1.0
    @State private var fogDepth: Float = 0.6

    // Watercolor Bleed
    @State private var wcBleedAmount: Float = 40.0
    @State private var watercolorWetness: Float = 0.6
    @State private var watercolorGrain: Float = 0.4
    @State private var watercolorFlowAngle: Float = 1.57

    // Plasma Flow
    @State private var plasmaCurl: Float = 0.2
    @State private var plasmaFlowScale: Float = 3.0
    @State private var plasmaSpeed: Float = 1.0
    @State private var plasmaMixSharp: Float = 0.3

    // Tilt Shift
    @State private var tiltFocusCenter: Float = 0.5
    @State private var tiltFocusWidth: Float = 0.15
    @State private var tiltMaxBlur: Float = 50.0
    @State private var tiltSaturation: Float = 1.4

    // Echo Trails
    @State private var echoTrailCount: Float = 5.0
    @State private var echoTrailSpread: Float = 0.06
    @State private var echoFadeRate: Float = 0.5
    @State private var echoDriftAngle: Float = 0.785

    // Fractal Mirror
    @State private var fractalSegments: Float = 6.0
    @State private var fractalZoom: Float = 1.5
    @State private var fractalRotation: Float = 0.3
    @State private var fractalSoftness: Float = 0.3

    // Liquid Silk
    @State private var silkRibbons: Float = 4.0
    @State private var silkFlowSpeed: Float = 1.0
    @State private var silkWarpAmt: Float = 0.15
    @State private var silkBlendMode: Float = 0.0

    // Molten Glass
    @State private var moltenViscosity: Float = 1.5
    @State private var moltenRefraction: Float = 40.0
    @State private var moltenHeat: Float = 0.3
    @State private var moltenClarity: Float = 0.2

    // Ink Diffusion
    @State private var inkSpread: Float = 0.3
    @State private var inkRings: Float = 3.0
    @State private var inkTurbulence: Float = 0.5
    @State private var inkSaturation: Float = 1.2

    // Magnetic Fluid
    @State private var magFieldStrength: Float = 0.15
    @State private var magPoles: Float = 3.0
    @State private var magFlowSpeed: Float = 1.0
    @State private var magBlur: Float = 20.0

    // Liquid Marble
    @State private var marbleVeinScale: Float = 4.0
    @State private var marbleSwirl: Float = 0.3
    @State private var marbleMixRatio: Float = 0.5
    @State private var marbleSmoothness: Float = 30.0

    // Horizon Melt
    @State private var horizonY: Float = 0.45
    @State private var horizonMelt: Float = 40.0
    @State private var horizonWaveSpeed: Float = 1.0
    @State private var horizonReflection: Float = 0.6

    // Fluid Mesh
    @State private var fluidGridSize: Float = 5.0
    @State private var fluidFluidity: Float = 0.3
    @State private var fluidBlendRadius: Float = 3.0
    @State private var fluidSatBoost: Float = 0.4

    // Gravity Pool
    @State private var gpPullStrength: Float = 0.15
    @State private var gpWellCount: Float = 3.0
    @State private var gpOrbitSpeed: Float = 0.5
    @State private var gpSoftness: Float = 25.0

    // Smoke Dissolve
    @State private var sdDissolve: Float = 0.4
    @State private var sdCurlScale: Float = 4.0
    @State private var sdRiseSpeed: Float = 1.5
    @State private var sdDensity: Float = 0.7

    // Tidal Pull
    @State private var tpAmplitude: Float = 30.0
    @State private var tpFrequency: Float = 3.0
    @State private var tpSpeed: Float = 1.0
    @State private var tpVerticalMix: Float = 0.3

    // Gaussian Splats
    @State private var splatDensity: Float = 6.0
    @State private var splatRadius: Float = 0.08
    @State private var splatJitter: Float = 0.6
    @State private var splatSat: Float = 0.4


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
        // Atmospheric Background Generators
        case meshGradient = "Mesh"
        case dreamBlur = "Dream"
        case liquidBloom = "Bloom"
        case heatMirage = "Mirage"
        case radialSmear = "Smear"
        case chromaticFog = "Fog"
        case watercolorBleed = "Watercolor"
        case plasmaFlow = "Plasma"
        case tiltShift = "Tilt"
        case echoTrails = "Echo BG"
        case fractalMirror = "Fractal"
        case liquidSilk = "Silk"
        case moltenGlass = "Molten"
        case inkDiffusion = "Ink BG"
        case magneticFluid = "Ferrofluid"
        case liquidMarble = "Marble"
        case horizonMelt = "Horizon"
        case fluidMesh = "Fluid"
        case gravityPool = "Pool BG"
        case smokeDissolve = "Dissolve"
        case tidalPull = "Tidal"
        case gaussianSplats = "Splats"
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
        switch activeEffect {
        case .luminousPool, .etherealAura,
             .meshGradient, .dreamBlur, .liquidBloom, .heatMirage,
             .radialSmear, .chromaticFog, .watercolorBleed, .plasmaFlow,
             .tiltShift, .echoTrails, .fractalMirror,
             .liquidSilk, .moltenGlass, .inkDiffusion, .magneticFluid,
             .liquidMarble, .horizonMelt, .fluidMesh, .gravityPool,
             .smokeDissolve, .tidalPull,
             .gaussianSplats:
            return true
        default:
            return false
        }
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

            case .meshGradient:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_meshGradient(
                            .float2(proxy.size),
                            .float(time),
                            .float(meshWarp),
                            .float(meshSmoothness),
                            .float(meshSpeed),
                            .float(meshSatBoost)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .dreamBlur:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_dreamBlur(
                            .float2(proxy.size),
                            .float(time),
                            .float(dreamBlurRadius),
                            .float(dreamWarpStrength),
                            .float(dreamBreatheSpeed),
                            .float(dreamSatBoost)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .liquidBloom:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_liquidBloom(
                            .float2(proxy.size),
                            .float(time),
                            .float(bloomRadius),
                            .float(bloomTurbulence),
                            .float(bloomFlowSpeed),
                            .float(bloomColorIntensity)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .heatMirage:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_heatMirage(
                            .float2(proxy.size),
                            .float(time),
                            .float(mirageDistortion),
                            .float(mirageWaveScale),
                            .float(mirageRiseSpeed),
                            .float(mirageBlur)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .radialSmear:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_radialSmear(
                            .float2(proxy.size),
                            .float(time),
                            .float(smearLength),
                            .float(smearRotation),
                            .float(smearPulseSpeed),
                            .float(smearClarity)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .chromaticFog:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_chromaticFog(
                            .float2(proxy.size),
                            .float(time),
                            .float(fogDensity),
                            .float(fogSeparation),
                            .float(fogDriftSpeed),
                            .float(fogDepth)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .watercolorBleed:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_watercolorBleed(
                            .float2(proxy.size),
                            .float(time),
                            .float(wcBleedAmount),
                            .float(watercolorWetness),
                            .float(watercolorGrain),
                            .float(watercolorFlowAngle)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .plasmaFlow:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_plasmaFlow(
                            .float2(proxy.size),
                            .float(time),
                            .float(plasmaCurl),
                            .float(plasmaFlowScale),
                            .float(plasmaSpeed),
                            .float(plasmaMixSharp)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .tiltShift:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_tiltShift(
                            .float2(proxy.size),
                            .float(time),
                            .float(tiltFocusCenter),
                            .float(tiltFocusWidth),
                            .float(tiltMaxBlur),
                            .float(tiltSaturation)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .echoTrails:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_echoTrails(
                            .float2(proxy.size),
                            .float(time),
                            .float(echoTrailCount),
                            .float(echoTrailSpread),
                            .float(echoFadeRate),
                            .float(echoDriftAngle)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .fractalMirror:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_fractalMirror(
                            .float2(proxy.size),
                            .float(time),
                            .float(fractalSegments),
                            .float(fractalZoom),
                            .float(fractalRotation),
                            .float(fractalSoftness)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .liquidSilk:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_liquidSilk(
                            .float2(proxy.size),
                            .float(time),
                            .float(silkRibbons),
                            .float(silkFlowSpeed),
                            .float(silkWarpAmt),
                            .float(silkBlendMode)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .moltenGlass:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_moltenGlass(
                            .float2(proxy.size),
                            .float(time),
                            .float(moltenViscosity),
                            .float(moltenRefraction),
                            .float(moltenHeat),
                            .float(moltenClarity)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .inkDiffusion:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_inkDiffusion(
                            .float2(proxy.size),
                            .float(time),
                            .float(inkSpread),
                            .float(inkRings),
                            .float(inkTurbulence),
                            .float(inkSaturation)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .magneticFluid:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_magneticFluid(
                            .float2(proxy.size),
                            .float(time),
                            .float(magFieldStrength),
                            .float(magPoles),
                            .float(magFlowSpeed),
                            .float(magBlur)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .liquidMarble:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_liquidMarble(
                            .float2(proxy.size),
                            .float(time),
                            .float(marbleVeinScale),
                            .float(marbleSwirl),
                            .float(marbleMixRatio),
                            .float(marbleSmoothness)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .horizonMelt:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_horizonMelt(
                            .float2(proxy.size),
                            .float(time),
                            .float(horizonY),
                            .float(horizonMelt),
                            .float(horizonWaveSpeed),
                            .float(horizonReflection)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .fluidMesh:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_fluidMesh(
                            .float2(proxy.size),
                            .float(time),
                            .float(fluidGridSize),
                            .float(fluidFluidity),
                            .float(fluidBlendRadius),
                            .float(fluidSatBoost)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .gravityPool:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_gravityPool(
                            .float2(proxy.size),
                            .float(time),
                            .float(gpPullStrength),
                            .float(gpWellCount),
                            .float(gpOrbitSpeed),
                            .float(gpSoftness)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .smokeDissolve:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_smokeDissolve(
                            .float2(proxy.size),
                            .float(time),
                            .float(sdDissolve),
                            .float(sdCurlScale),
                            .float(sdRiseSpeed),
                            .float(sdDensity)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .tidalPull:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_tidalPull(
                            .float2(proxy.size),
                            .float(time),
                            .float(tpAmplitude),
                            .float(tpFrequency),
                            .float(tpSpeed),
                            .float(tpVerticalMix)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
                    )
                }

            case .gaussianSplats:
                base.visualEffect { content, proxy in
                    content.layerEffect(
                        ShaderLibrary.bcs_gaussianSplats(
                            .float2(proxy.size),
                            .float(time),
                            .float(splatDensity),
                            .float(splatRadius),
                            .float(splatJitter),
                            .float(splatSat)
                        ),
                        maxSampleOffset: CGSize(width: 1, height: 1)
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

            case .luminousPool, .etherealAura,
                 .meshGradient, .dreamBlur, .liquidBloom, .heatMirage,
                 .radialSmear, .chromaticFog, .watercolorBleed, .plasmaFlow,
                 .tiltShift, .echoTrails, .fractalMirror,
             .liquidSilk, .moltenGlass, .inkDiffusion, .magneticFluid,
             .liquidMarble, .horizonMelt, .fluidMesh, .gravityPool,
             .smokeDissolve, .tidalPull,
             .gaussianSplats:
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

                    // --- Atmospheric Background Generators ---

                    case .meshGradient:
                        slider("Warp", $meshWarp, 0...1)
                        slider("Smoothness", $meshSmoothness, 1...5)
                        slider("Speed", $meshSpeed, 0.2...3)
                        slider("Saturation", $meshSatBoost, 0...1)

                    case .dreamBlur:
                        slider("Blur", $dreamBlurRadius, 20...120)
                        slider("Warp", $dreamWarpStrength, 0...1)
                        slider("Breathe", $dreamBreatheSpeed, 0.2...2)
                        slider("Saturation", $dreamSatBoost, 0...1)

                    case .liquidBloom:
                        slider("Bloom", $bloomRadius, 0.1...0.8)
                        slider("Turbulence", $bloomTurbulence, 0...1)
                        slider("Flow", $bloomFlowSpeed, 0.2...2)
                        slider("Vibrancy", $bloomColorIntensity, 0.5...2)

                    case .heatMirage:
                        slider("Distortion", $mirageDistortion, 5...60)
                        slider("Waves", $mirageWaveScale, 2...15)
                        slider("Rise Speed", $mirageRiseSpeed, 0.5...3)
                        slider("Haze", $mirageBlur, 0...1)

                    case .radialSmear:
                        slider("Smear", $smearLength, 0.05...0.4)
                        slider("Rotation", $smearRotation, 0...1)
                        slider("Pulse", $smearPulseSpeed, 0.2...2)
                        slider("Clarity", $smearClarity, 0...1)

                    case .chromaticFog:
                        slider("Density", $fogDensity, 20...100)
                        slider("Separation", $fogSeparation, 0...30)
                        slider("Drift", $fogDriftSpeed, 0.2...2)
                        slider("Depth", $fogDepth, 0.3...1)

                    case .watercolorBleed:
                        slider("Bleed", $wcBleedAmount, 10...80)
                        slider("Wetness", $watercolorWetness, 0...1)
                        slider("Paper", $watercolorGrain, 0...1)
                        slider("Flow Angle", $watercolorFlowAngle, 0...6.28)

                    case .plasmaFlow:
                        slider("Curl", $plasmaCurl, 0.05...0.4)
                        slider("Scale", $plasmaFlowScale, 1...5)
                        slider("Speed", $plasmaSpeed, 0.2...2)
                        slider("Original Mix", $plasmaMixSharp, 0...1)

                    case .tiltShift:
                        slider("Focus Y", $tiltFocusCenter, 0.2...0.8)
                        slider("Focus Width", $tiltFocusWidth, 0.05...0.3)
                        slider("Blur", $tiltMaxBlur, 20...80)
                        slider("Saturation", $tiltSaturation, 1...2)

                    case .echoTrails:
                        slider("Echoes", $echoTrailCount, 2...8)
                        slider("Spread", $echoTrailSpread, 0.02...0.15)
                        slider("Fade", $echoFadeRate, 0.3...0.8)
                        slider("Direction", $echoDriftAngle, 0...6.28)

                    case .fractalMirror:
                        slider("Segments", $fractalSegments, 2...12)
                        slider("Zoom", $fractalZoom, 0.5...3)
                        slider("Rotation", $fractalRotation, 0...1)
                        slider("Softness", $fractalSoftness, 0...1)

                    case .liquidSilk:
                        slider("Ribbons", $silkRibbons, 2...6)
                        slider("Flow", $silkFlowSpeed, 0.2...2)
                        slider("Warp", $silkWarpAmt, 0.05...0.3)
                        slider("Blend", $silkBlendMode, 0...1)

                    case .moltenGlass:
                        slider("Viscosity", $moltenViscosity, 0.5...3)
                        slider("Refraction", $moltenRefraction, 10...80)
                        slider("Heat", $moltenHeat, 0...1)
                        slider("Clarity", $moltenClarity, 0...1)

                    case .inkDiffusion:
                        slider("Spread", $inkSpread, 0.1...0.5)
                        slider("Rings", $inkRings, 1...5)
                        slider("Turbulence", $inkTurbulence, 0...1)
                        slider("Saturation", $inkSaturation, 0.5...2)

                    case .magneticFluid:
                        slider("Field", $magFieldStrength, 0.05...0.3)
                        slider("Poles", $magPoles, 2...6)
                        slider("Flow", $magFlowSpeed, 0.2...2)
                        slider("Blur", $magBlur, 5...40)

                    case .liquidMarble:
                        slider("Veins", $marbleVeinScale, 1...8)
                        slider("Swirl", $marbleSwirl, 0.1...0.5)
                        slider("Mix", $marbleMixRatio, 0...1)
                        slider("Smooth", $marbleSmoothness, 10...60)

                    case .horizonMelt:
                        slider("Horizon", $horizonY, 0.3...0.7)
                        slider("Melt", $horizonMelt, 10...80)
                        slider("Waves", $horizonWaveSpeed, 0.2...2)
                        slider("Reflect", $horizonReflection, 0...1)

                    case .fluidMesh:
                        slider("Grid", $fluidGridSize, 3...8)
                        slider("Fluidity", $fluidFluidity, 0.1...0.5)
                        slider("Blend", $fluidBlendRadius, 1...5)
                        slider("Saturation", $fluidSatBoost, 0...1)

                    case .gravityPool:
                        slider("Pull", $gpPullStrength, 0.05...0.3)
                        slider("Wells", $gpWellCount, 1...4)
                        slider("Orbit", $gpOrbitSpeed, 0.1...1)
                        slider("Softness", $gpSoftness, 10...50)

                    case .smokeDissolve:
                        slider("Dissolve", $sdDissolve, 0...1)
                        slider("Curl Scale", $sdCurlScale, 2...8)
                        slider("Rise", $sdRiseSpeed, 0.5...3)
                        slider("Density", $sdDensity, 0.3...1)

                    case .tidalPull:
                        slider("Amplitude", $tpAmplitude, 10...60)
                        slider("Frequency", $tpFrequency, 1...6)
                        slider("Speed", $tpSpeed, 0.3...2)
                        slider("Vertical", $tpVerticalMix, 0...1)

                    case .gaussianSplats:
                        slider("Density", $splatDensity, 2...12)
                        slider("Radius", $splatRadius, 0.02...0.2)
                        slider("Jitter", $splatJitter, 0...1)
                        slider("Saturation", $splatSat, 0...1)

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
