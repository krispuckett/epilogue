import SwiftUI
import MetalKit
import simd

// MARK: - Advanced Gradient Shader View
struct AdvancedGradientShaderView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.clearColor = MTLClearColor(red: 0.11, green: 0.105, blue: 0.102, alpha: 1.0)
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = false
        mtkView.preferredFramesPerSecond = 60
        
        context.coordinator.setupMetalWithCustomShaders(mtkView)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        var startTime: Date = Date()
        
        // Gradient parameters buffer
        var parametersBuffer: MTLBuffer!
        
        struct GradientParameters {
            var time: Float = 0
            var resolution: simd_float2 = simd_float2(1, 1)
            var padding: simd_float2 = simd_float2(0, 0) // Align to 16 bytes
        }
        
        func setupMetal(_ mtkView: MTKView) {
            guard let device = mtkView.device else { return }
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            // Create shader library
            let library = device.makeDefaultLibrary()
            let vertexFunction = library?.makeFunction(name: "advancedGradientVertex")
            let fragmentFunction = library?.makeFunction(name: "advancedGradientFragment")
            
            // Create pipeline
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            
            // Enable blending for smooth gradients
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
            
            // Create parameters buffer
            var params = GradientParameters()
            parametersBuffer = device.makeBuffer(bytes: &params, length: MemoryLayout<GradientParameters>.size, options: [])
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
            }
            
            // Update time
            let elapsed = Float(Date().timeIntervalSince(startTime))
            
            // Update parameters
            var params = GradientParameters()
            params.time = elapsed
            params.resolution = simd_float2(Float(view.drawableSize.width), Float(view.drawableSize.height))
            parametersBuffer.contents().copyMemory(from: &params, byteCount: MemoryLayout<GradientParameters>.size)
            
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.setFragmentBuffer(parametersBuffer, offset: 0, index: 0)
            
            // Draw fullscreen quad
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Metal Shaders
extension AdvancedGradientShaderView {
    static let metalShaders = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct GradientParameters {
        float time;
        float2 resolution;
        float2 padding;
    };
    
    // Vertex shader - creates fullscreen quad
    vertex float4 advancedGradientVertex(uint vertexID [[vertex_id]]) {
        float2 positions[4] = {
            float2(-1, -1),
            float2( 1, -1),
            float2(-1,  1),
            float2( 1,  1)
        };
        return float4(positions[vertexID], 0, 1);
    }
    
    // Simplex noise function for organic movement
    float2 hash(float2 p) {
        p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
        return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
    }
    
    float noise(float2 p) {
        const float K1 = 0.366025404; // (sqrt(3)-1)/2
        const float K2 = 0.211324865; // (3-sqrt(3))/6
        
        float2 i = floor(p + (p.x + p.y) * K1);
        float2 a = p - i + (i.x + i.y) * K2;
        float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
        float2 b = a - o + K2;
        float2 c = a - 1.0 + 2.0 * K2;
        
        float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
        float3 n = h * h * h * h * float3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
        
        return dot(n, float3(70.0));
    }
    
    // Fractal Brownian Motion for complex patterns
    float fbm(float2 p, float time) {
        float value = 0.0;
        float amplitude = 0.5;
        float frequency = 1.0;
        
        for (int i = 0; i < 5; i++) {
            value += amplitude * noise(p * frequency + time * 0.1);
            frequency *= 2.0;
            amplitude *= 0.5;
        }
        
        return value;
    }
    
    // Fragment shader - creates animated gradient
    fragment float4 advancedGradientFragment(float4 position [[position]],
                                            constant GradientParameters& params [[buffer(0)]]) {
        float2 uv = position.xy / params.resolution;
        float2 p = uv * 2.0 - 1.0;
        p.x *= params.resolution.x / params.resolution.y;
        
        float time = params.time;
        
        // Multiple gradient layers with different phases
        float layer1 = fbm(p * 0.5 + float2(0.0, time * 0.05), time);
        float layer2 = fbm(p * 0.3 + float2(time * 0.03, 0.0), time * 1.2);
        float layer3 = fbm(p * 0.7 - float2(time * 0.02, time * 0.04), time * 0.8);
        
        // Combine layers with sine wave modulation
        float combined = layer1 * 0.4 + layer2 * 0.3 + layer3 * 0.3;
        combined += sin(time * 0.2 + p.y * 2.0) * 0.1;
        combined += sin(time * 0.15 - p.x * 1.5) * 0.1;
        
        // Create rotation effect
        float angle = time * 0.05 + combined * 0.3;
        float2 rotatedP = float2(
            p.x * cos(angle) - p.y * sin(angle),
            p.x * sin(angle) + p.y * cos(angle)
        );
        
        // Add scaling variation
        float scale = 1.0 + sin(time * 0.1) * 0.2;
        float pattern = fbm(rotatedP * scale, time);
        
        // Amber/orange gradient colors
        float3 color1 = float3(1.0, 0.35, 0.1);   // Deep orange
        float3 color2 = float3(1.0, 0.55, 0.26);  // Warm amber
        float3 color3 = float3(1.0, 0.7, 0.4);    // Light amber
        float3 color4 = float3(0.9, 0.3, 0.15);   // Dark orange
        
        // Mix colors based on noise patterns
        float mixFactor1 = smoothstep(-0.5, 0.5, combined + pattern * 0.5);
        float mixFactor2 = smoothstep(-0.3, 0.7, layer2 - layer3);
        
        float3 gradientColor = mix(color1, color2, mixFactor1);
        gradientColor = mix(gradientColor, color3, mixFactor2);
        gradientColor = mix(gradientColor, color4, smoothstep(0.3, 0.9, pattern));
        
        // Add subtle vignette
        float vignette = 1.0 - length(p) * 0.5;
        vignette = smoothstep(0.0, 1.0, vignette);
        
        // Apply Perlin noise displacement
        float displacement = noise(p * 3.0 + time * 0.2) * 0.1;
        gradientColor += displacement;
        
        // Final color with transparency for glass effect overlay
        return float4(gradientColor * vignette, 0.85);
    }
    """
}

// MARK: - Shader Library Manager
class ShaderLibraryManager {
    static let shared = ShaderLibraryManager()
    private var compiledLibrary: MTLLibrary?
    
    func getLibrary(for device: MTLDevice) -> MTLLibrary? {
        if let library = compiledLibrary {
            return library
        }
        
        do {
            compiledLibrary = try device.makeLibrary(source: AdvancedGradientShaderView.metalShaders,
                                                     options: nil)
            return compiledLibrary
        } catch {
            print("Failed to compile shader library: \(error)")
            return device.makeDefaultLibrary()
        }
    }
}

// MARK: - Fix Coordinator to use custom library
extension AdvancedGradientShaderView.Coordinator {
    func setupMetalWithCustomShaders(_ mtkView: MTKView) {
        guard let device = mtkView.device else { return }
        self.device = device
        self.commandQueue = device.makeCommandQueue()
        
        // Get custom shader library
        guard let library = ShaderLibraryManager.shared.getLibrary(for: device) else {
            print("Failed to get shader library")
            return
        }
        
        let vertexFunction = library.makeFunction(name: "advancedGradientVertex")
        let fragmentFunction = library.makeFunction(name: "advancedGradientFragment")
        
        // Continue with pipeline setup...
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
        
        var params = GradientParameters()
        parametersBuffer = device.makeBuffer(bytes: &params, length: MemoryLayout<GradientParameters>.size, options: [])
    }
}