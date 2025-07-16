import SwiftUI
import MetalKit
import simd

struct MetalLiteraryView: UIViewRepresentable {
    var style: AmbientStyle = .cosmicOrb
    
    enum AmbientStyle: String {
        case cosmicOrb = "ambientFragment"
        case abstractFireplace = "fireplaceFragment"
    }
    
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
        
        context.coordinator.style = style
        
        // Setup Metal after view is configured
        DispatchQueue.main.async {
            context.coordinator.setupMetal(mtkView: mtkView)
        }
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        if context.coordinator.style != style {
            context.coordinator.style = style
            context.coordinator.setupShaders()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var parent: MetalLiteraryView
        var metalDevice: MTLDevice?
        var metalCommandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        
        var style: AmbientStyle = .cosmicOrb
        var time: Float = 0.0
        var isInitialized = false
        
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
            isInitialized = true
        }
        
        func setupShaders() {
            guard let device = metalDevice else {
                print("Metal device not available")
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
                    print("Failed to load library from bundle: \(error)")
                }
            }
            
            guard let defaultLibrary = library else {
                print("Failed to create Metal library - check that LiteraryCompanion.metal is added to the target")
                return
            }
            
            // List all functions in the library for debugging
            let functionNames = defaultLibrary.functionNames
            print("Available Metal functions: \(functionNames)")
            
            // Create render pipeline
            guard let vertexFunction = defaultLibrary.makeFunction(name: "ambientVertex") else {
                print("Failed to find ambientVertex function in Metal shader")
                return
            }
            
            guard let fragmentFunction = defaultLibrary.makeFunction(name: style.rawValue) else {
                print("Failed to find \(style.rawValue) function in Metal shader")
                return
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create render pipeline state: \(error)")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No special handling needed for full-screen quad
        }
        
        func draw(in view: MTKView) {
            guard isInitialized else {
                print("Metal not initialized yet")
                return
            }
            
            guard let device = metalDevice,
                  let commandQueue = metalCommandQueue,
                  let pipelineState = pipelineState else {
                print("Metal components missing - device: \(metalDevice != nil), queue: \(metalCommandQueue != nil), pipeline: \(pipelineState != nil)")
                return
            }
            
            guard let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            
            time += 0.016  // ~60fps
            
            // Render pass
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1.0)
            
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                renderEncoder.setRenderPipelineState(pipelineState)
                renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
                
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
    @State private var selectedStyle: MetalLiteraryView.AmbientStyle = .cosmicOrb
    
    var body: some View {
        ZStack {
            if !metalFailed {
                MetalLiteraryView(style: selectedStyle)
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
            
            // Style switcher (optional, for testing)
            if false {  // Set to true to enable style switching
                VStack {
                    Spacer()
                        .frame(height: 60) // Space for Dynamic Island
                    HStack {
                        Button(action: {
                            selectedStyle = .cosmicOrb
                            print("Selected Cosmic Orb")
                        }) {
                            Text("Cosmic Orb")
                                .padding()
                                .background(selectedStyle == .cosmicOrb ? Color.orange : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            selectedStyle = .abstractFireplace
                            print("Selected Fireplace")
                        }) {
                            Text("Fireplace")
                                .padding()
                                .background(selectedStyle == .abstractFireplace ? Color.orange : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    Spacer()
                }
                .foregroundStyle(.white)
                .background(Color.black.opacity(0.5))
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
