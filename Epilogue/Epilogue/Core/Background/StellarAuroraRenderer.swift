import Foundation
import Metal
import MetalKit
import simd

struct StellarAuroraVertexUniforms {
    var modelViewMatrix: simd_float4x4 = matrix_identity_float4x4
    var projectionMatrix: simd_float4x4 = matrix_identity_float4x4
    var textureMatrix: simd_float4x4 = matrix_identity_float4x4
}

struct StellarAuroraFragmentUniforms {
    var position: SIMD2<Float> = .zero
    var time: Float = 0
    var pressed: Float = 0
    var mousePosition: SIMD2<Float> = .zero
    var resolution: SIMD2<Float> = SIMD2<Float>(1, 1)
    var themeColor: SIMD3<Float> = SIMD3<Float>(repeating: 1)
    var intensity: Float = 1
    var speed: Float = 1
    var padding: Float = 0
}

enum StellarAuroraRendererError: Error {
    case missingFunction(name: String)
    case failedToCreateSampler
}

final class StellarAuroraRenderer {
    let pipelineState: MTLRenderPipelineState
    let samplerState: MTLSamplerState
    let vertexDescriptor: MTLVertexDescriptor

    init(device: MTLDevice,
         library: MTLLibrary? = nil,
         colorPixelFormat: MTLPixelFormat = .bgra8Unorm,
         sampleCount: Int = 1) throws {
        let library = try library ?? device.makeDefaultLibrary(bundle: .main)

        guard let vertexFunction = library.makeFunction(name: "stellarAuroraVertex") else {
            throw StellarAuroraRendererError.missingFunction(name: "stellarAuroraVertex")
        }

        guard let fragmentFunction = library.makeFunction(name: "stellarAuroraFragment") else {
            throw StellarAuroraRendererError.missingFunction(name: "stellarAuroraFragment")
        }

        let vertexDescriptor = StellarAuroraRenderer.makeVertexDescriptor()
        self.vertexDescriptor = vertexDescriptor

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor.sampleCount = sampleCount

        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.normalizedCoordinates = true

        guard let sampler = device.makeSamplerState(descriptor: samplerDescriptor) else {
            throw StellarAuroraRendererError.failedToCreateSampler
        }

        samplerState = sampler
    }

    func encode(into encoder: MTLRenderCommandEncoder,
                vertexBuffer: MTLBuffer,
                vertexCount: Int = 6,
                vertexUniforms: inout StellarAuroraVertexUniforms,
                fragmentUniforms: inout StellarAuroraFragmentUniforms,
                backgroundTexture: MTLTexture,
                customTexture: MTLTexture? = nil) {
        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&vertexUniforms,
                               length: MemoryLayout<StellarAuroraVertexUniforms>.stride,
                               index: 2)

        encoder.setFragmentTexture(backgroundTexture, index: 0)
        if let customTexture {
            encoder.setFragmentTexture(customTexture, index: 1)
            encoder.setFragmentSamplerState(samplerState, index: 1)
        }

        encoder.setFragmentSamplerState(samplerState, index: 0)
        fragmentUniforms.padding = 0
        encoder.setFragmentBytes(&fragmentUniforms,
                                 length: MemoryLayout<StellarAuroraFragmentUniforms>.stride,
                                 index: 0)

        encoder.drawPrimitives(type: .triangle,
                               vertexStart: 0,
                               vertexCount: vertexCount)
    }

    private static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let descriptor = MTLVertexDescriptor()

        descriptor.attributes[0].format = .float3
        descriptor.attributes[0].offset = 0
        descriptor.attributes[0].bufferIndex = 0

        descriptor.attributes[1].format = .float2
        descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        descriptor.attributes[1].bufferIndex = 0

        descriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride + MemoryLayout<SIMD2<Float>>.stride
        descriptor.layouts[0].stepFunction = .perVertex

        return descriptor
    }
}
