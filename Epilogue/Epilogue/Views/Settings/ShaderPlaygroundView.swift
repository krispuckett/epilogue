import SwiftUI
import MetalKit
import simd

// MARK: - Shader Playground View
struct ShaderPlaygroundView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPressed = false
    @State private var selectedShader: ShaderType = .aurora
    @State private var shaderSize: CGFloat = 300

    // Ambient Wave parameters
    @State private var speed: Float = 2.40
    @State private var circleRadius: Float = 0.19
    @State private var freqMix: Float = 0.20
    @State private var smoothing: Float = 1.45
    @State private var bloomIntensity: Float = 0.53
    @State private var rotation: Float = 0.17
    @State private var cycleColors = false

    enum ShaderType: String, CaseIterable {
        case aurora = "Aurora (Current)"
        case ambientWave = "Ambient Wave"

        var description: String {
            switch self {
            case .aurora:
                return "Current production shader with aurora effect"
            case .ambientWave:
                return "Adjustable aurora with turbulence and color cycling"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Shader preview
                        VStack(spacing: 16) {
                            ZStack {
                                // Checkered background to see transparency
                                CheckeredBackground()
                                    .frame(width: shaderSize, height: shaderSize)
                                    .clipShape(Circle())

                                // Shader
                                switch selectedShader {
                                case .aurora:
                                    MetalShaderView(isPressed: $isPressed, size: CGSize(width: shaderSize, height: shaderSize))
                                        .frame(width: shaderSize, height: shaderSize)
                                case .ambientWave:
                                    AmbientWaveShaderView(
                                        isPressed: $isPressed,
                                        size: CGSize(width: shaderSize, height: shaderSize),
                                        speed: $speed,
                                        circleRadius: $circleRadius,
                                        freqMix: $freqMix,
                                        smoothing: $smoothing,
                                        bloomIntensity: $bloomIntensity,
                                        rotation: $rotation,
                                        cycleColors: $cycleColors
                                    )
                                    .frame(width: shaderSize, height: shaderSize)
                                }
                            }
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isPressed.toggle()
                                }
                                SensoryFeedback.light()

                                // Auto-release after 0.5s
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        isPressed = false
                                    }
                                }
                            }

                            Text(isPressed ? "PRESSED" : "TAP TO PRESS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(1.2)
                        }
                        .padding(.top, 40)

                        // Shader selector
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SELECT SHADER")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(1.2)

                            VStack(spacing: 12) {
                                ForEach(ShaderType.allCases, id: \.self) { shader in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedShader = shader
                                        }
                                        SensoryFeedback.light()
                                    } label: {
                                        HStack(spacing: 16) {
                                            // Radio button
                                            ZStack {
                                                Circle()
                                                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 2)
                                                    .frame(width: 20, height: 20)

                                                if selectedShader == shader {
                                                    Circle()
                                                        .fill(DesignSystem.Colors.primaryAccent)
                                                        .frame(width: 12, height: 12)
                                                }
                                            }

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(shader.rawValue)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(.white)

                                                Text(shader.description)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }

                                            Spacer()
                                        }
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(selectedShader == shader ? 0.08 : 0.04))
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(
                                                    selectedShader == shader ? DesignSystem.Colors.primaryAccent.opacity(0.3) : Color.white.opacity(0.06),
                                                    lineWidth: 1
                                                )
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // Size slider
                        VStack(alignment: .leading, spacing: 16) {
                            Text("SIZE: \(Int(shaderSize))pt")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .kerning(1.2)

                            Slider(value: $shaderSize, in: 100...400, step: 50)
                                .tint(DesignSystem.Colors.primaryAccent)
                        }
                        .padding(.horizontal, 20)

                        // Ambient Wave parameters
                        if selectedShader == .ambientWave {
                            VStack(spacing: 20) {
                                // Color cycling toggle
                                HStack {
                                    Label {
                                        Text("Cycle Theme Colors")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.white)
                                    } icon: {
                                        Image(systemName: "paintpalette")
                                            .foregroundStyle(DesignSystem.Colors.primaryAccent)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $cycleColors)
                                        .labelsHidden()
                                        .tint(DesignSystem.Colors.primaryAccent)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.04))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                                }

                                Divider()
                                    .background(Color.white.opacity(0.1))

                                // Speed slider
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("SPEED: \(String(format: "%.2f", speed))x")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .kerning(1.2)

                                    Slider(value: $speed, in: 0.1...5.0, step: 0.01)
                                        .tint(DesignSystem.Colors.primaryAccent)
                                }

                                // Circle Radius slider
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("CIRCLE SIZE: \(String(format: "%.2f", circleRadius))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .kerning(1.2)

                                    Slider(value: $circleRadius, in: 0.05...0.5, step: 0.01)
                                        .tint(DesignSystem.Colors.primaryAccent)
                                }

                                // Frequency Mix slider
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("FREQUENCY: \(String(format: "%.2f", freqMix))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .kerning(1.2)

                                    Slider(value: $freqMix, in: 0.0...1.0, step: 0.01)
                                        .tint(DesignSystem.Colors.primaryAccent)
                                }

                                // Smoothing slider
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("SMOOTHING: \(String(format: "%.2f", smoothing))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .kerning(1.2)

                                    Slider(value: $smoothing, in: 0.0...2.0, step: 0.01)
                                        .tint(DesignSystem.Colors.primaryAccent)
                                }

                                // Bloom Intensity slider
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("BLOOM: \(String(format: "%.2f", bloomIntensity))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .kerning(1.2)

                                    Slider(value: $bloomIntensity, in: 0.0...1.0, step: 0.01)
                                        .tint(DesignSystem.Colors.primaryAccent)
                                }

                                // Rotation slider
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("ROTATION: \(String(format: "%.2f", rotation))")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .kerning(1.2)

                                    Slider(value: $rotation, in: 0.0...1.0, step: 0.01)
                                        .tint(DesignSystem.Colors.primaryAccent)
                                }

                                // Reset button
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        speed = 2.40
                                        circleRadius = 0.19
                                        freqMix = 0.20
                                        smoothing = 1.45
                                        bloomIntensity = 0.53
                                        rotation = 0.17
                                    }
                                    SensoryFeedback.light()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Reset Parameters")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(DesignSystem.Colors.primaryAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(DesignSystem.Colors.primaryAccent.opacity(0.2), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .transition(.opacity)
                        }

                        // Info
                        VStack(alignment: .leading, spacing: 12) {
                            Label {
                                Text("Shaders are rendered with Metal at 60fps")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                            } icon: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Label {
                                Text("Press state animates shader properties")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                            } icon: {
                                Image(systemName: "hand.tap")
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Label {
                                Text("Colors adapt to current theme")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.7))
                            } icon: {
                                Image(systemName: "paintbrush")
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Shader Playground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
    }
}

// MARK: - Checkered Background
struct CheckeredBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let squareSize: CGFloat = 20
            let columns = Int(geometry.size.width / squareSize) + 1
            let rows = Int(geometry.size.height / squareSize) + 1

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<columns {
                        let isEven = (row + col) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(isEven ? Color.white.opacity(0.05) : Color.white.opacity(0.02))
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Ambient Wave Shader View (Converted from JSON)
struct AmbientWaveShaderView: UIViewRepresentable {
    @Binding var isPressed: Bool
    let size: CGSize
    @Binding var speed: Float
    @Binding var circleRadius: Float
    @Binding var freqMix: Float
    @Binding var smoothing: Float
    @Binding var bloomIntensity: Float
    @Binding var rotation: Float
    @Binding var cycleColors: Bool
    let accentColor: Color = DesignSystem.Colors.primaryAccent

    class Coordinator: NSObject, MTKViewDelegate {
        var parent: AmbientWaveShaderView
        var renderer: AmbientWaveMetalRenderer!
        var colorCycleTime: Float = 0

        init(_ parent: AmbientWaveShaderView) {
            self.parent = parent
            super.init()
            renderer = AmbientWaveMetalRenderer()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            renderer.viewSizeChanged(to: size)
        }

        func draw(in view: MTKView) {
            guard renderer != nil else { return }
            renderer.isPressed = parent.isPressed
            renderer.speed = parent.speed
            renderer.circleRadius = parent.circleRadius
            renderer.freqMix = parent.freqMix
            renderer.smoothing = parent.smoothing
            renderer.bloomIntensity = parent.bloomIntensity
            renderer.rotation = parent.rotation

            // Color cycling
            if parent.cycleColors {
                colorCycleTime += 0.005
                let hue = fmod(colorCycleTime, 1.0)
                let uiColor = UIColor(hue: CGFloat(hue), saturation: 0.8, brightness: 0.9, alpha: 1.0)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                renderer.themeColor = SIMD3<Float>(Float(r), Float(g), Float(b))
            } else {
                let uiColor = UIColor(parent.accentColor)
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                renderer.themeColor = SIMD3<Float>(Float(r), Float(g), Float(b))
            }

            renderer.draw(in: view)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else {
            return mtkView
        }

        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false

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

        let viewSize = CGSize(width: size.width, height: size.height)
        if uiView.drawableSize.width != viewSize.width || uiView.drawableSize.height != viewSize.height {
            uiView.drawableSize = viewSize
        }
    }
}

// MARK: - Ambient Wave Metal Renderer
class AmbientWaveMetalRenderer: NSObject {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var pipelineState: MTLRenderPipelineState!
    private var startTime = CACurrentMediaTime()
    private var currentSize: CGSize = .zero
    private var frameCount = 0

    var isPressed: Bool = false
    var themeColor: SIMD3<Float> = SIMD3<Float>(1.0, 0.549, 0.259)
    var speed: Float = 2.40
    var circleRadius: Float = 0.19
    var freqMix: Float = 0.20
    var smoothing: Float = 1.45
    var bloomIntensity: Float = 0.53
    var rotation: Float = 0.17

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

        // Ambient Wave shader - converted from GLSL to Metal
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        struct Uniforms {
            float time;
            float2 resolution;
            float pressed;
            float3 themeColor;
            float speed;
            float circleRadius;
            float freqMix;
            float smoothing;
            float bloomIntensity;
            float rotation;
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

        float getSdf(float2 st, float iter, float md, float radius) {
            return sdCircle(st, radius);
        }

        float2 turb(float2 pos, float t, float it, float md, float2 mPos, float freqMix) {
            float2x2 rot = float2x2(0.6, -0.8, 0.8, 0.6);
            float freq = 2.0 + (15.0 - 2.0) * freqMix;
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

        fragment float4 fragmentShader(
            VertexOut in [[stage_in]],
            constant Uniforms &uniforms [[buffer(0)]]
        ) {
            float2 uv = in.texCoord;

            float3 pp = float3(0.0);
            float3 bloom = float3(0.0);
            float t = uniforms.time * uniforms.speed;

            float2 aspect = float2(uniforms.resolution.x / uniforms.resolution.y, 1.0);
            float2 mousePos = float2(0.0);
            float2 uPos = float2(0.5, 0.5);
            float2 pos = (uv * aspect - uPos * aspect);
            float md = 1.0;

            // Animated rotation like original shader
            float rotationAngle = (uniforms.rotation + t * 0.07) * -2.0 * PI;
            float2x2 rotMatrix = float2x2(cos(rotationAngle), -sin(rotationAngle),
                                           sin(rotationAngle), cos(rotationAngle));
            pos = rotMatrix * pos;

            float bm = 0.05;
            float2 prevPos = turb(pos, t, -1.0 / ITERATIONS, md, mousePos, uniforms.freqMix);
            float spacing = TAU;

            for(float i = 1.0; i < ITERATIONS + 1.0; i++) {
                float iter = i / ITERATIONS;
                float2 st = turb(pos, t, iter * spacing, md, mousePos, uniforms.freqMix);

                float d = abs(getSdf(st, iter, md, uniforms.circleRadius));
                float pd = distance(st, prevPos);
                prevPos = st;

                float dynamicBlur = exp2(pd * 2.0 * 1.442695) - 1.0;
                float ds = smoothstep(0.0, 0.02 * bm + max(dynamicBlur * uniforms.smoothing, 0.001), d);

                float3 color = pal(
                    iter * 0.19 + 1.0,
                    float3(0.5),
                    float3(0.5),
                    float3(1.0),
                    float3(0.0, 0.24313725, 0.23137255)
                );

                float invd = 1.0 / max(d + dynamicBlur, 0.001);
                pp += (ds - 1.0) * color;
                bloom += clamp(invd, 0.0, 250.0) * color;
            }

            pp *= 1.0 / ITERATIONS;
            bloom = bloom / (bloom + 2e4);

            float3 color = (-pp + bloom * 3.0 * uniforms.bloomIntensity);
            color *= 1.2;
            color += (randFibo(in.position.xy) - 0.5) / 255.0;
            color = Tonemap_Reinhard(color);

            // Apply theme color tint
            color *= uniforms.themeColor * 1.5;

            float pressBoost = mix(1.0, 1.3, uniforms.pressed);
            color *= pressBoost;

            float2 center = uv - 0.5;
            float dist = length(center);
            float circleMask = 1.0 - smoothstep(0.35, 0.5, dist);

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
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            #if DEBUG
            print("✅ AmbientWave shader initialized successfully")
            #endif
        } catch {
            print("⚠️ Error creating Ambient Wave pipeline state: \(error)")
        }
    }

    func viewSizeChanged(to size: CGSize) {
        currentSize = size
    }

    func draw(in view: MTKView) {
        guard pipelineState != nil else {
            #if DEBUG
            print("⚠️ AmbientWave: pipelineState is nil, skipping draw")
            #endif
            return
        }

        if currentSize != view.drawableSize {
            viewSizeChanged(to: view.drawableSize)
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
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

        #if DEBUG
        frameCount += 1
        if frameCount % 60 == 0 {
            print("🎬 AmbientWave frame \(frameCount), time: \(currentTime)")
        }
        #endif

        struct Uniforms {
            var time: Float
            var resolution: SIMD2<Float>
            var pressed: Float
            var themeColor: SIMD3<Float>
            var speed: Float
            var circleRadius: Float
            var freqMix: Float
            var smoothing: Float
            var bloomIntensity: Float
            var rotation: Float
        }

        var uniforms = Uniforms(
            time: currentTime,
            resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            pressed: Float(isPressed ? 1.0 : 0.0),
            themeColor: themeColor,
            speed: speed,
            circleRadius: circleRadius,
            freqMix: freqMix,
            smoothing: smoothing,
            bloomIntensity: bloomIntensity,
            rotation: rotation
        )

        renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - Preview
#Preview {
    ShaderPlaygroundView()
}
