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
            print("Metal device not available")
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
            print("Metal device not available")
            return
        }
        self.device = device
        commandQueue = device.makeCommandQueue()

        // Create shader library from source
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
            float2 positions[6] = {
                float2(-1.0, -1.0),
                float2( 1.0, -1.0),
                float2(-1.0,  1.0),
                float2( 1.0, -1.0),
                float2( 1.0,  1.0),
                float2(-1.0,  1.0)
            };

            VertexOut out;
            out.position = float4(positions[vertexID], 0.0, 1.0);
            out.texCoord = (positions[vertexID] + 1.0) * 0.5;
            out.texCoord.y = 1.0 - out.texCoord.y;
            return out;
        }

        // Palette function for aurora colors
        float3 pal(float t, float3 a, float3 b, float3 c, float3 d) {
            return a + b * cos(6.28318 * (c * t + d));
        }

        // Improved turbulence with dynamic rotation
        float2 turb(float2 pos, float t, float iter) {
            float freq = mix(2.0, 15.0, 0.67);
            float amp = 1.0;
            float time = t * 0.4 + 1.0; // Slightly faster turbulence

            for(int i = 0; i < 4; i++) {
                // Dynamic rotation per iteration for more complexity
                float angle = 0.6 + float(i) * 0.1;
                float2x2 rot = float2x2(cos(angle), -sin(angle), sin(angle), cos(angle));

                float2 s = sin(freq * (pos * rot) + float(i) * time + iter);
                pos += amp * rot[0] * s / freq;
                amp *= mix(1.0, max(s.y, s.x), 1.0);
                freq *= 1.4;
            }
            return pos;
        }

        fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                     constant float &time [[buffer(0)]],
                                     constant float2 &resolution [[buffer(1)]],
                                     constant float &pressed [[buffer(2)]],
                                     constant float3 &themeColor [[buffer(3)]]) {
            float2 uv = in.texCoord;
            float2 aspect = float2(resolution.x/resolution.y, 1.0);

            // Faster, more dynamic animation with press speed coupling
            float speedBoost = mix(1.8, 2.2, pressed); // Much faster
            float pressBoost = mix(1.0, 1.3, pressed);

            // Sine wave distortion (Layer 1)
            float2 waveCoord = uv * 2.0 - 1.0;
            float waveTime = time * 1.4 * speedBoost; // Faster waves
            float frequency = 20.0 * 0.856;
            float amp = 0.42 * 0.4; // More wave amplitude for drama
            float waveX = sin((waveCoord.y + 0.5) * frequency + waveTime * 1.047) * amp;
            float waveY = sin((waveCoord.x - 0.5) * frequency + waveTime * 1.047) * amp;
            waveCoord += float2(waveX * 0.58, waveY * 0.58);

            // Aurora effect (Layer 2)
            float2 pos = (uv * aspect - float2(0.5, 0.4991) * aspect);
            float3 pp = float3(0.0);
            float3 bloom = float3(0.0);
            float t = time * speedBoost * 1.5 + 1.0; // Faster aurora

            // Faster continuous rotation
            float rotation = (0.0486 + time * 0.07) * -2.0 * 3.14159;
            float2x2 rotMatrix = float2x2(cos(rotation), -sin(rotation),
                                         sin(rotation), cos(rotation));
            pos = rotMatrix * pos;

            // Aurora iterations
            const int ITERATIONS = 24;
            float spacing = mix(1.0, 6.28318, 0.43);

            for(int i = 1; i < ITERATIONS + 1; i++) {
                float iter = float(i) / float(ITERATIONS);
                float2 st = turb(pos, t, iter * spacing);

                float d = length(st) - 0.224;
                d = abs(d);

                float ds = smoothstep(0.0, 0.02, d);

                // Use theme color passed from Swift with enhanced saturation
                float3 exactColor = themeColor; // Will be #FF8C42 (1.0, 0.549, 0.259) for amber
                // Boost saturation for more vibrant amber
                exactColor = mix(exactColor, float3(1.0, 0.4, 0.1), 0.3); // Push toward pure amber
                float intensity = (1.0 + iter * 0.6); // Higher intensity range
                float3 color = exactColor * intensity;

                float invd = 1.0 / max(d, 0.001);
                pp += (ds - 1.0) * color;
                bloom += clamp(invd * 1.5, 0.0, 350.0) * color; // Increased bloom brightness
            }

            pp *= 1.0 / float(ITERATIONS);
            bloom = bloom / (bloom + 2e4);

            // Only apply color to the aurora lines, not the background
            float3 color = (-pp + bloom * 6.0); // Increased bloom for more vibrant lines

            // Don't boost everything - just the lines
            color = max(color, 0.0); // Remove negative values that create background

            // Light tonemap just for the lines - reduced for more intensity
            color = color / (1.0 + color * 0.1);

            // Ensure color is only on the bright parts (the lines)
            color = color * step(0.01, length(color)); // Zero out very dark areas

            // Press animation
            color *= pressBoost;

            // Calculate alpha based ONLY on aurora brightness
            float luminance = dot(color, float3(0.299, 0.587, 0.114));

            // No radial mask - let the aurora define its own shape
            // Alpha is purely based on how bright the aurora is
            float alpha = smoothstep(0.0, 0.1, luminance);
            alpha = clamp(alpha, 0.0, 1.0);

            // Premultiply alpha for correct blending
            return float4(color * alpha, alpha);
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

            // Correct alpha blending for premultiplied alpha
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Error creating pipeline state: \(error)")
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

        // Ensure clear to transparent
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