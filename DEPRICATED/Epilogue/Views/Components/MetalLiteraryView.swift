import SwiftUI
import MetalKit
import simd

struct MetalLiteraryView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            #if DEBUG
            print("Metal is not supported on this device")
            #endif
            return mtkView
        }
        
        mtkView.device = device
        mtkView.delegate = context.coordinator
        mtkView.preferredFramesPerSecond = 30 // Reduce from 60 for battery life
        mtkView.enableSetNeedsDisplay = true // Only redraw when needed
        mtkView.framebufferOnly = true // Optimize for display only
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0.11, green: 0.105, blue: 0.102, alpha: 1.0)
        
        // Setup Metal after view is configured
        DispatchQueue.main.async {
            context.coordinator.setupMetal(mtkView: mtkView)
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Nothing to update
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalLiteraryView
        var metalDevice: MTLDevice?
        var metalCommandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        
        var time: Float = 0.0
        var isInitialized = false
        
        init(_ parent: MetalLiteraryView) {
            self.parent = parent
            super.init()
        }
        
        func setupMetal(mtkView: MTKView) {
            guard let device = mtkView.device else {
                #if DEBUG
                print("Metal device not available")
                #endif
                return
            }
            metalDevice = device
            
            guard let commandQueue = device.makeCommandQueue() else {
                #if DEBUG
                print("Failed to create command queue")
                #endif
                return
            }
            metalCommandQueue = commandQueue
            
            setupShaders()
            isInitialized = true
        }
        
        func setupShaders() {
            guard let device = metalDevice else {
                #if DEBUG
                print("Metal device not available")
                #endif
                return
            }
            
            // Try to load the Metal library
            var library: MTLLibrary? = nil
            
            // First try the default library
            library = device.makeDefaultLibrary()
            
            // If that fails, try loading from the bundle
            if library == nil {
                let bundle = Bundle.main
                do {
                    library = try device.makeDefaultLibrary(bundle: bundle)
                } catch {
                    #if DEBUG
                    print("Failed to load library from bundle: \(error)")
                    #endif
                }
            }
            
            guard let defaultLibrary = library else {
                #if DEBUG
                print("Failed to create Metal library - check that LiteraryCompanion.metal is added to the target")
                #endif
                return
            }
            
            // List all functions in the library for debugging
            let functionNames = defaultLibrary.functionNames
            #if DEBUG
            print("Available Metal functions: \(functionNames)")
            #endif
            
            // Create render pipeline
            guard let vertexFunction = defaultLibrary.makeFunction(name: "ambientVertex") else {
                #if DEBUG
                print("Failed to find ambientVertex function in Metal shader")
                #endif
                return
            }
            
            guard let fragmentFunction = defaultLibrary.makeFunction(name: "ambientFragment") else {
                #if DEBUG
                print("Failed to find ambientFragment function in Metal shader")
                #endif
                return
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                #if DEBUG
                print("Failed to create render pipeline state: \(error)")
                #endif
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No special handling needed for full-screen quad
        }
        
        func draw(in view: MTKView) {
            guard isInitialized else {
                #if DEBUG
                print("Metal not initialized yet")
                #endif
                return
            }
            
            guard let device = metalDevice,
                  let commandQueue = metalCommandQueue,
                  let pipelineState = pipelineState else {
                #if DEBUG
                print("Metal components missing - device: \(metalDevice != nil), queue: \(metalCommandQueue != nil), pipeline: \(pipelineState != nil)")
                #endif
                return
            }
            
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            
            time += 0.033  // ~30fps to match reduced frame rate
            
            // Render pass
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1.0)
            
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                renderEncoder.setRenderPipelineState(pipelineState)
                
                // Pass time and resolution
                var currentTime = time
                var viewportSize = SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height))
                
                renderEncoder.setFragmentBytes(&currentTime, length: MemoryLayout<Float>.size, index: 0)
                renderEncoder.setFragmentBytes(&viewportSize, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
                
                // Draw full-screen quad (6 vertices for 2 triangles)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                renderEncoder.endEncoding()
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - Calm Literary Background
struct CalmLiteraryBackground: View {
    @State private var metalFailed = false
    
    var body: some View {
        ZStack {
            if !metalFailed {
                MetalLiteraryView()
                    .ignoresSafeArea()
                    .onAppear {
                        if MTLCreateSystemDefaultDevice() == nil {
                            metalFailed = true
                        }
                    }
            } else {
                // Fallback to SwiftUI animation
                FallbackAmbientView()
            }
        }
    }
}

// MARK: - Fallback View
struct FallbackAmbientView: View {
    @State private var phase: Double = 0
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.08, green: 0.07, blue: 0.07)
                .ignoresSafeArea()
            
            // Simple animated gradient orb
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 1.0, green: 0.55, blue: 0.26).opacity(0.6),
                    Color(red: 0.9, green: 0.35, blue: 0.1).opacity(0.3),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 200
            )
            .scaleEffect(1 + sin(phase) * 0.1)
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    phase = .pi * 2
                }
            }
        }
    }
}
