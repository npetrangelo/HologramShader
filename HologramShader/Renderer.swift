//
//  Renderer.swift
//  HologramShader
//
//  Created by qe on 4/14/22.
//

import Foundation
import MetalKit
import ModelIO
import simd
 
struct VertexUniforms {
    var modelMatrix: float4x4
    var viewProjectionMatrix: float4x4
    var normalMatrix: float3x3;
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let mtkView: MTKView
    var vertexDescriptor: MTLVertexDescriptor!
    var meshes: [MTKMesh] = []
    var renderPipeline: MTLRenderPipelineState!
    let commandQueue: MTLCommandQueue
    var time: Float = 0
    let depthStencilState: MTLDepthStencilState
    var baseColorTexture: MTLTexture?
    let samplerState: MTLSamplerState
    
    init(view: MTKView, device: MTLDevice) {
        self.mtkView = view
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.depthStencilState = Renderer.buildDepthStencilState(device: device)
        self.samplerState = Renderer.buildSamplerState(device: device)
        super.init()
        loadResources()
        buildPipeline()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // TODO
    }
    
    func draw(in view: MTKView) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        time += 1 / Float(mtkView.preferredFramesPerSecond)
        let angle = -time
        let modelMatrix = float4x4(rotationAbout: SIMD3<Float>(0, 1, 0), by: angle) *  float4x4(scaleBy: 2)
        let cameraWorldPosition = SIMD3<Float>(0, 0, 2)
        let viewMatrix = float4x4(translationBy: -cameraWorldPosition)
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
        let viewProjectionmatrix = projectionMatrix * viewMatrix
        var vertexUniforms = VertexUniforms(modelMatrix: modelMatrix, viewProjectionMatrix: viewProjectionmatrix, normalMatrix: modelMatrix.normalMatrix)
        
        let material = Material()
        material.specularPower = 200
        material.specularColor = SIMD3<Float>(0.8, 0.8, 0.8)
        let light0 = Light(worldPosition: SIMD3<Float>(2,  2, 2), color: SIMD3<Float>(1, 0, 0))
        let light1 = Light(worldPosition: SIMD3<Float>(-2, 2, 2), color: SIMD3<Float>(0, 1, 0))
        let light2 = Light(worldPosition: SIMD3<Float>(0, -2, 2), color: SIMD3<Float>(0, 0, 1))
        var fragmentUniforms = FragmentUniforms(cameraWorldPosition: cameraWorldPosition, ambientLightColor: SIMD3<Float>(0.1, 0.1, 0.1), specularColor: material.specularColor, specularPower: material.specularPower, light0: light0, light1: light1, light2: light2)
        
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.setRenderPipelineState(renderPipeline)
            commandEncoder.setDepthStencilState(depthStencilState)
            commandEncoder.setFragmentTexture(baseColorTexture, index: 0)
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
            commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
            commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.size, index: 0)
            for mesh in meshes {
                let vertexBuffer = mesh.vertexBuffers.first!
                commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
                
                for submesh in mesh.submeshes {
                    let indexBuffer = submesh.indexBuffer
                    commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: indexBuffer.offset)
                }
            }
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    func loadResources() {
        let modelURL = Bundle.main.url(forResource: "teapot", withExtension: "obj")!
        
        let vertexDescriptor = Renderer.getMDLVertexDescriptor()
        self.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        do {
            (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
        } catch {
            fatalError("Could not extract meshes from Model I/O asset")
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [.generateMipmaps: true, .SRGB: true]
        baseColorTexture = try? textureLoader.newTexture(name: "tiles_baseColor", scaleFactor: 1.0, bundle: nil, options: options)
        
    }
    
    func buildPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
                
        // Setup the output pixel format to match the pixel format of the metal kit view
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        
        Renderer.configAlphaBlend(pipelineDescriptor: pipelineDescriptor)
        
        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
    }
    
    static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }
    
    static func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    class func getMDLVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: MemoryLayout<Float>.size * 3, bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: MemoryLayout<Float>.size * 6, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        return vertexDescriptor
    }
    
    class func configAlphaBlend(pipelineDescriptor: MTLRenderPipelineDescriptor) {
        let renderbufferAttachment = pipelineDescriptor.colorAttachments[0]!
        renderbufferAttachment.isBlendingEnabled = true
        renderbufferAttachment.rgbBlendOperation = MTLBlendOperation.add
        renderbufferAttachment.alphaBlendOperation = MTLBlendOperation.add
        renderbufferAttachment.sourceRGBBlendFactor = MTLBlendFactor.sourceAlpha
        renderbufferAttachment.sourceAlphaBlendFactor = MTLBlendFactor.sourceAlpha
        renderbufferAttachment.destinationRGBBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
        renderbufferAttachment.destinationAlphaBlendFactor = MTLBlendFactor.oneMinusSourceAlpha
    }
}
