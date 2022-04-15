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
 
struct Uniforms {
    var modelViewMatrix: float4x4
    var projectionMatrix: float4x4
}

struct Lights {
    var position: SIMD3<Float>
    var color: SIMD3<Float>
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let mtkView: MTKView
    var vertexDescriptor: MTLVertexDescriptor!
    var meshes: [MTKMesh] = []
    var renderPipeline: MTLRenderPipelineState!
    let commandQueue: MTLCommandQueue
    var time: Float = 0
    
    init(view: MTKView, device: MTLDevice) {
        self.mtkView = view
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
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
        let viewMatrix = float4x4(translationBy: SIMD3<Float>(0, 0, -2))
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        let projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
        let modelViewMatrix = viewMatrix * modelMatrix
        var uniforms = Uniforms(modelViewMatrix: modelViewMatrix, projectionMatrix: projectionMatrix)
        
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.setRenderPipelineState(renderPipeline)
            commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
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
        
        Renderer.configAlphaBlend(pipelineDescriptor: pipelineDescriptor)
        
        do {
            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
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
