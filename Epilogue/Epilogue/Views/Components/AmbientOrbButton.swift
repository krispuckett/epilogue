import SwiftUI
import MetalKit
import simd

// MARK: - Metal Shader View
struct MetalShaderView: UIViewRepresentable {
    @Binding var isPressed: Bool
    let size: CGSize
    let accentColor: Color = DesignSystem.Colors.primaryAccent // Theme-aware color

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalShaderView
        var renderer: OrbMetalRenderer!

        init(_ parent: MetalShaderView) {
            self.parent = parent
            super.init()
            renderer = OrbMetalRenderer()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.viewSizeChanged(to: size)
        }

        func draw(in view: MTKView) {
            renderer.isPressed = parent.isPressed
            // Pass theme color to renderer
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
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

        // Proper configuration for transparency
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
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var startTime = CACurrentMediaTime()

    // Texture management
    private var currentSize: CGSize = .zero

    // Parameters
    var isPressed: Bool = false
    var themeColor: SIMD3<Float> = SIMD3<Float>(1.0, 0.549, 0.259) // #FF8C42 exact
    var fogAmount: Float = 0.0  // Start with no fog for simplicity

    override init() {
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

        // Ambient Wave shader - high quality production version
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
            float2 positions[6] = {
                float2(-1.0, -1.0), float2( 1.0, -1.0), float2(-1.0,  1.0),
                float2( 1.0, -1.0), float2( 1.0,  1.0), float2(-1.0,  1.0)
            };

            VertexOut out;
            out.position = float4(positions[vertexID], 0.0, 1.0);
            out.texCoord = (positions[vertexID] + 1.0) * 0.5;
            out.texCoord.y = 1.0 - out.texCoord.y;
            return out;
        }

        constant float PI = 3.14159265359;
        constant float TAU = 6.28318530718;
        constant float ITERATIONS = 36.0;
        constant float SPEED = 2.40;
        constant float CIRCLE_SIZE = 0.19;
        constant float FREQ_MIX = 0.20;
        constant float BLOOM_INTENSITY = 0.53;
        constant float SMOOTHING = 1.45;
        constant float ROTATION_BASE = 0.17;

        float3 pal(float t, float3 a, float3 b, float3 c, float3 d) {
            return a + b * cos(TAU * (c * t + d));
        }

        float3 Tonemap_Reinhard(float3 x) {
            x *= 4.0;
            return x / (1.0 + x);
        }

        float sdCircle(float2 st, float r) {
            return length(st) - r;
        }

        float2 turb(float2 pos, float t, float it, float md, float2 mPos) {
            float2x2 rot = float2x2(0.6, -0.8, 0.8, 0.6);
            float freq = 2.0 + (15.0 - 2.0) * FREQ_MIX;
            float amp = 0.27 * md;
            float xp = 1.4;
            float time = t * 0.4;

            for(float i = 0.0; i < 4.0; i++) {
                float2 s = sin(freq * ((pos - mPos) * rot) + (i * time + it));
                pos += amp * rot[0] * s / freq;
                rot = rot * float2x2(0.6, -0.8, 0.8, 0.6);
                amp *= max(s.y, s.x);
                freq *= xp;
            }
            return pos;
        }

        float luma(float3 color) {
            return dot(color, float3(0.299, 0.587, 0.114));
        }

        uint2 pcg2d(uint2 v) {
            v = v * 1664525u + 1013904223u;
            v.x += v.y * v.y * 1664525u + 1013904223u;
            v.y += v.x * v.x * 1664525u + 1013904223u;
            v ^= v >> 16u;
            v.x += v.y * v.y * 1664525u + 1013904223u;
            v.y += v.x * v.x * 1664525u + 1013904223u;
            return v;
        }

        float randFibo(float2 p) {
            uint2 v = as_type<uint2>(p);
            v = pcg2d(v);
            uint r = v.x ^ v.y;
            return float(r) / float(0xffffffffu);
        }

        fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                     constant float &time [[buffer(0)]],
                                     constant float2 &resolution [[buffer(1)]],
                                     constant float &pressed [[buffer(2)]],
                                     constant float3 &themeColor [[buffer(3)]]) {
            float2 uv = in.texCoord;

            float3 pp = float3(0.0);
            float3 bloom = float3(0.0);
            float t = time * SPEED;

            float2 aspect = float2(resolution.x / resolution.y, 1.0);
            float2 mousePos = float2(0.0);
            float2 uPos = float2(0.5, 0.5);  // CENTERED
            float2 pos = (uv * aspect - uPos * aspect);
            float md = 1.0;

            float rotationAngle = (ROTATION_BASE + t * 0.07) * -2.0 * PI;
            float2x2 rotMatrix = float2x2(cos(rotationAngle), -sin(rotationAngle),
                                           sin(rotationAngle), cos(rotationAngle));
            pos = rotMatrix * pos;

            float bm = 0.05;
            float2 prevPos = turb(pos, t, -1.0 / ITERATIONS, md, mousePos);
            float spacing = TAU;

            for(float i = 1.0; i < ITERATIONS + 1.0; i++) {
                float iter = i / ITERATIONS;
                float2 st = turb(pos, t, iter * spacing, md, mousePos);

                float d = abs(sdCircle(st, CIRCLE_SIZE));
                float pd = distance(st, prevPos);
                prevPos = st;

                float dynamicBlur = exp2(pd * 2.0 * 1.442695) - 1.0;
                float ds = smoothstep(0.0, 0.02 * bm + max(dynamicBlur * SMOOTHING, 0.001), d);

                float3 color = pal(
                    iter * 0.19 + 1.0,
                    float3(0.5),
                    float3(0.5),
                    float3(1.0),
                    float3(0.0, 0.24313725, 0.23137255)
                );

                float invd = 1.0 / max(d + dynamicBlur, 0.001);
                pp += (ds - 1.0) * color;
                bloom += clamp(invd * BLOOM_INTENSITY, 0.0, 250.0) * color;
            }

            pp *= 1.0 / ITERATIONS;
            bloom = bloom / (bloom + 2e4);

            float3 color = (-pp + bloom * 3.0 * BLOOM_INTENSITY);
            color *= 1.2;
            color += (randFibo(in.position.xy) - 0.5) / 255.0;
            color = Tonemap_Reinhard(color);

            // Apply theme color with saturation boost
            color *= themeColor * 1.5;

            float pressBoost = mix(1.0, 1.3, pressed);
            color *= pressBoost;

            float2 center = uv - 0.5;
            float dist = length(center);
            float circleMask = 1.0 - smoothstep(0.42, 0.52, dist);  // Even larger visible area

            float luminance = luma(color);
            float alpha = circleMask * smoothstep(0.0, 0.2, luminance);

            return float4(color, alpha);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            let vertexFunction = library.makeFunction(name: "vertexShader")
            let fragmentFunction = library.makeFunction(name: "fragmentShader")

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb

            // Standard alpha blending (not premultiplied)
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

    func draw(in view: MTKView) {
        // Check if size changed
        if currentSize != view.drawableSize {
            viewSizeChanged(to: view.drawableSize)
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }

        // Clear to fully transparent
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Pass uniforms
        let currentTime = Float(CACurrentMediaTime() - startTime)
        var time = currentTime
        var resolution = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
        var pressed = Float(isPressed ? 1.0 : 0.0)
        var themeColorCopy = themeColor

        renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        renderEncoder.setFragmentBytes(&pressed, length: MemoryLayout<Float>.size, index: 2)
        renderEncoder.setFragmentBytes(&themeColorCopy, length: MemoryLayout<SIMD3<Float>>.size, index: 3)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    // Render to a custom texture (for exporting)
    func renderToTexture(_ texture: MTLTexture, commandQueue: MTLCommandQueue, size: CGSize) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
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

        // Pass uniforms
        let currentTime = Float(CACurrentMediaTime() - startTime)
        var time = currentTime
        var resolution = SIMD2<Float>(Float(size.width), Float(size.height))
        var pressed = Float(isPressed ? 1.0 : 0.0)
        var themeColorCopy = themeColor

        renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        renderEncoder.setFragmentBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        renderEncoder.setFragmentBytes(&pressed, length: MemoryLayout<Float>.size, index: 2)
        renderEncoder.setFragmentBytes(&themeColorCopy, length: MemoryLayout<SIMD3<Float>>.size, index: 3)

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
            // Just the Metal shader with NO background or glass
            MetalShaderView(isPressed: $isPressed, size: CGSize(width: size, height: size))
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
        .buttonStyle(OrbButtonStyle(isPressed: $isPressed))
        // NO glass effect - let the shader be completely transparent
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