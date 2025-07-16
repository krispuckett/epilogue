import SwiftUI
import MetalKit
import simd

struct MetalLiteraryView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return mtkView
        }
        
        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = false
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        
        // Delay setup until view has proper size
        DispatchQueue.main.async {
            context.coordinator.setupMetal(mtkView: mtkView)
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update logic if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalLiteraryView
        var metalDevice: MTLDevice?
        var metalCommandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var computePipelineState: MTLComputePipelineState?
        
        // Particle system
        var particleBuffer: MTLBuffer?
        var particleCount = 5000
        var time: Float = 0.0
        
        // Fluid simulation textures
        var velocityTexture: MTLTexture?
        var densityTexture: MTLTexture?
        var pressureTexture: MTLTexture?
        
        // Track initialization state
        var isInitialized = false
        
        struct Particle {
            var position: SIMD2<Float>
            var velocity: SIMD2<Float>
            var life: Float
            var size: Float
            var heat: Float
            var turbulence: Float
        }
        
        init(_ parent: MetalLiteraryView) {
            self.parent = parent
            super.init()
        }
        
        func setupMetal(mtkView: MTKView) {
            guard let device = mtkView.device else { 
                print("Metal device not available")
                return 
            }
            metalDevice = device
            
            guard let commandQueue = device.makeCommandQueue() else {
                print("Failed to create command queue")
                return
            }
            metalCommandQueue = commandQueue
            
            setupShaders()
            setupBuffers()
            
            // Only setup textures if we have a valid size
            if mtkView.drawableSize.width > 0 && mtkView.drawableSize.height > 0 {
                setupTextures(size: mtkView.drawableSize)
            }
            
            isInitialized = true
        }
        
        func setupShaders() {
            // Load the default library
            guard let device = metalDevice,
                  let defaultLibrary = device.makeDefaultLibrary() else {
                print("Failed to create default library")
                return
            }
            
            // Create compute pipeline
            if let computeFunction = defaultLibrary.makeFunction(name: "updateParticles") {
                do {
                    computePipelineState = try device.makeComputePipelineState(function: computeFunction)
                } catch {
                    print("Failed to create compute pipeline state: \(error)")
                }
            }
            
            // Create render pipeline
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "particleVertex")
            pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "particleFragment")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create render pipeline state: \(error)")
            }
        }
        
        func setupBuffers() {
            guard let device = metalDevice else { return }
            
            // Initialize particles
            var particles = [Particle]()
            for i in 0..<particleCount {
                let angle = Float(i) * 2.0 * Float.pi / Float(particleCount)
                let radius = Float.random(in: 0.1...0.5)
                
                let particle = Particle(
                    position: SIMD2<Float>(
                        0.5 + radius * cos(angle),
                        0.5 + radius * sin(angle)
                    ),
                    velocity: SIMD2<Float>(
                        Float.random(in: -0.001...0.001),
                        Float.random(in: -0.001...0.001)
                    ),
                    life: Float.random(in: 0.5...1.0),
                    size: Float.random(in: 0.5...1.5),
                    heat: 0.0,
                    turbulence: Float.random(in: 0.5...1.5)
                )
                particles.append(particle)
            }
            
            let bufferSize = particles.count * MemoryLayout<Particle>.stride
            particleBuffer = device.makeBuffer(bytes: particles, length: bufferSize, options: [.storageModeShared])
        }
        
        func setupTextures(size: CGSize) {
            guard let device = metalDevice else { return }
            
            // Ensure valid dimensions
            let width = max(1, Int(size.width))
            let height = max(1, Int(size.height))
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba32Float,
                width: width,
                height: height,
                mipmapped: false
            )
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            textureDescriptor.storageMode = .shared
            
            velocityTexture = device.makeTexture(descriptor: textureDescriptor)
            densityTexture = device.makeTexture(descriptor: textureDescriptor)
            pressureTexture = device.makeTexture(descriptor: textureDescriptor)
            
            if velocityTexture == nil || densityTexture == nil || pressureTexture == nil {
                print("Failed to create textures")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Only setup textures if Metal is already initialized
            guard isInitialized, metalDevice != nil else { return }
            setupTextures(size: size)
        }
        
        func draw(in view: MTKView) {
            guard isInitialized,
                  metalDevice != nil,
                  metalCommandQueue != nil,
                  pipelineState != nil,
                  computePipelineState != nil,
                  particleBuffer != nil else {
                // Silently return if not ready yet
                return
            }
            
            guard let drawable = view.currentDrawable,
                  let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
            
            time += 0.016
            
            // Compute pass for particle physics
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder(),
               let computePipeline = computePipelineState,
               let buffer = particleBuffer {
                computeEncoder.setComputePipelineState(computePipeline)
                computeEncoder.setBuffer(buffer, offset: 0, index: 0)
                computeEncoder.setBytes(&time, length: MemoryLayout<Float>.size, index: 1)
                
                let threadsPerGrid = MTLSize(width: particleCount, height: 1, depth: 1)
                let maxThreadsPerThreadgroup = computePipeline.maxTotalThreadsPerThreadgroup
                let threadsPerThreadgroup = MTLSize(width: min(256, maxThreadsPerThreadgroup), height: 1, depth: 1)
                
                computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
                computeEncoder.endEncoding()
            }
            
            // Render pass
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1.0)
            
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
               let renderPipeline = pipelineState,
               let buffer = particleBuffer {
                renderEncoder.setRenderPipelineState(renderPipeline)
                renderEncoder.setVertexBuffer(buffer, offset: 0, index: 0)
                renderEncoder.setVertexBytes(&time, length: MemoryLayout<Float>.size, index: 1)
                
                var viewportSize = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
                renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
                
                renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
                renderEncoder.endEncoding()
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}