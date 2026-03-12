import SwiftUI
import MetalKit
import simd

// MARK: - Metal Shader View
struct MetalShaderView: UIViewRepresentable {
    @Binding var isPressed: Bool
    let size: CGSize
    let accentColor: Color
    var config: OrbShaderConfig?
    var iterations: Int32?

    init(isPressed: Binding<Bool>, size: CGSize,
         accentColor: Color = DesignSystem.Colors.primaryAccent,
         config: OrbShaderConfig? = nil,
         iterations: Int32? = nil) {
        self._isPressed = isPressed
        self.size = size
        self.accentColor = accentColor
        self.config = config
        self.iterations = iterations
    }

    /// Auto LOD: scale iterations to pixel size when not explicitly set.
    private var resolvedIterations: Int32 {
        if let explicit = iterations { return explicit }
        let pixelSize = max(size.width, size.height) * UIScreen.main.scale
        return Int32(max(10, min(36, Int(pixelSize / 3))))
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalShaderView
        var renderer: OrbMetalRenderer?

        init(_ parent: MetalShaderView) {
            self.parent = parent
            super.init()
            renderer = OrbMetalRenderer(iterations: parent.resolvedIterations)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer?.viewSizeChanged(to: size)
        }

        func draw(in view: MTKView) {
            guard let renderer = renderer else { return }
            renderer.isPressed = parent.isPressed
            if let cfg = parent.config {
                renderer.config = cfg
            }
            let uiColor = UIColor(parent.accentColor)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            renderer.themeColor = SIMD3<Float>(Float(r), Float(g), Float(b))
            renderer.draw(in: view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            #if DEBUG
            print("Metal device not available")
            #endif
            return mtkView
        }

        mtkView.device = device
        mtkView.delegate = context.coordinator

        // FPS throttle: small orbs (< 60pt) get 30fps, larger get 60fps
        mtkView.preferredFramesPerSecond = size.width <= 60 ? 30 : 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        // Transparency
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.layer.backgroundColor = UIColor.clear.cgColor
        mtkView.layer.isOpaque = false
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.parent = self
        uiView.isPaused = false
    }
}

// MARK: - Metal Renderer
class OrbMetalRenderer: NSObject {
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var startTime = CACurrentMediaTime()
    private var currentSize: CGSize = .zero

    // Smooth press interpolation
    private var smoothedPress: Float = 0.0

    // Parameters
    var isPressed: Bool = false
    var themeColor: SIMD3<Float> = SIMD3<Float>(1.0, 0.549, 0.259)
    var config: OrbShaderConfig = .golden

    private let iterations: Int32

    init(iterations: Int32 = 20, config: OrbShaderConfig = .golden) {
        self.iterations = iterations
        self.config = config
        super.init()
        setupMetal()
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            #if DEBUG
            print("Metal device not available")
            #endif
            return
        }
        self.device = device
        commandQueue = device.makeCommandQueue()

        guard let library = device.makeDefaultLibrary() else {
            #if DEBUG
            print("Default Metal library not found")
            #endif
            return
        }

        do {
            let constants = MTLFunctionConstantValues()
            var iters = iterations
            constants.setConstantValue(&iters, type: .int, index: 0)

            let vertexFunction = library.makeFunction(name: "ambientOrbVertex")
            let fragmentFunction = try library.makeFunction(name: "ambientOrbFragment",
                                                            constantValues: constants)

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb

            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            #if DEBUG
            print("Error creating pipeline state: \(error)")
            #endif
        }
    }

    func viewSizeChanged(to size: CGSize) {
        currentSize = size
    }

    private func encodeUniforms(to encoder: MTLRenderCommandEncoder, time: Float, resolution: SIMD2<Float>) {
        var t = time
        var res = resolution

        // Smooth press: interpolate toward target each frame
        let targetPress: Float = isPressed ? 1.0 : 0.0
        smoothedPress += (targetPress - smoothedPress) * config.pressSmoothing
        var pressValue = smoothedPress

        var color = themeColor
        var configCopy = config

        encoder.setFragmentBytes(&t, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentBytes(&res, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.setFragmentBytes(&pressValue, length: MemoryLayout<Float>.size, index: 2)
        encoder.setFragmentBytes(&color, length: MemoryLayout<SIMD3<Float>>.size, index: 3)
        encoder.setFragmentBytes(&configCopy, length: MemoryLayout<OrbShaderConfig>.stride, index: 4)
    }

    func draw(in view: MTKView) {
        if currentSize != view.drawableSize {
            viewSizeChanged(to: view.drawableSize)
        }

        guard let commandQueue = commandQueue,
              let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        let currentTime = Float(CACurrentMediaTime() - startTime)
        let resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        encodeUniforms(to: renderEncoder, time: currentTime, resolution: resolution)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Renders a single frame to UIImage for widgets/Live Activities.
    func renderToImage(size: CGSize, atTime time: Float = 2.5) -> UIImage? {
        guard let device = device,
              let commandQueue = commandQueue,
              let pipelineState = pipelineState else { return nil }

        let width = Int(size.width)
        let height = Int(size.height)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: width, height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }

        let rpd = MTLRenderPassDescriptor()
        rpd.colorAttachments[0].texture = texture
        rpd.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        rpd.colorAttachments[0].loadAction = .clear
        rpd.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else { return nil }
        encoder.setRenderPipelineState(pipelineState)

        let resolution = SIMD2<Float>(Float(width), Float(height))
        encodeUniforms(to: encoder, time: time, resolution: resolution)

        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let bytesPerRow = 4 * width
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(&bytes, bytesPerRow: bytesPerRow,
                         from: MTLRegion(origin: .init(), size: .init(width: width, height: height, depth: 1)),
                         mipmapLevel: 0)

        guard let dataProvider = CGDataProvider(data: Data(bytes) as CFData),
              let cgImage = CGImage(
                  width: width, height: height,
                  bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                  provider: dataProvider, decode: nil,
                  shouldInterpolate: true, intent: .defaultIntent
              ) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    func renderToTexture(_ texture: MTLTexture, commandQueue: MTLCommandQueue, size: CGSize) {
        guard let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        let currentTime = Float(CACurrentMediaTime() - startTime)
        let resolution = SIMD2<Float>(Float(size.width), Float(size.height))
        encodeUniforms(to: renderEncoder, time: currentTime, resolution: resolution)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

// MARK: - Ambient Orb Button with Glass
struct AmbientOrbButton: View {
    @State private var isPressed = false

    let action: () -> Void
    let size: CGFloat

    init(size: CGFloat = 60, action: @escaping () -> Void) {
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            MetalShaderView(isPressed: $isPressed, size: CGSize(width: size, height: size))
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
        .buttonStyle(OrbButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Custom button style for press animations
struct OrbButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
                if newValue {
                    SensoryFeedback.impact(.light)
                }
            }
    }
}

// MARK: - Integration Helper
extension AmbientOrbButton {
    static func openAmbientMode(with book: Book? = nil) {
        if let book = book {
            SimplifiedAmbientCoordinator.shared.openAmbientReading(with: book)
        } else {
            SimplifiedAmbientCoordinator.shared.openAmbientReading()
        }
    }
}
