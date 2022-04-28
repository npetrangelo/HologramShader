//
//  Renderer.swift
//  HologramShader
//
//  Created by qe on 4/14/22.
//

import Foundation
import MetalKit
import simd

struct VertexUniforms {
    var viewProjectionMatrix: float4x4
    var modelMatrix: float4x4
    var normalMatrix: float3x3
}

struct SceneUniforms {
    var numPointLights = Int32(0)
    var numSunLights = Int32(0)
    var frequency = Float(300)
    var cameraWorldPosition = SIMD3<Float>(0, 0, 0)
    var ambientLightColor = SIMD3<Float>(0.1, 0.1, 0.1)
}

struct NodeUniforms {
    var specularColor = SIMD3<Float>(0, 0, 0)
    var specularPower = Float(0)
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let renderPipeline: MTLRenderPipelineState
    let pipelineReflection: MTLRenderPipelineReflection?
    let depthStencilState: MTLDepthStencilState
    let samplerState: MTLSamplerState
    let scene: Scene
    
    var time: Float = 0
    var viewMatrix = matrix_identity_float4x4
    var projectionMatrix = matrix_identity_float4x4

    init(view: MTKView, device: MTLDevice) {
        self.device = device
        commandQueue = device.makeCommandQueue()!
        samplerState = Renderer.buildSamplerState(device: device)
        depthStencilState = Renderer.buildDepthStencilState(device: device)
        
        let vertexDescriptor = Renderer.buildVertexDescriptor()
        (renderPipeline, pipelineReflection) = Renderer.buildPipeline(device: device, view: view, vertexDescriptor: vertexDescriptor)
        scene = Renderer.buildScene(device: device, vertexDescriptor: vertexDescriptor)
        super.init()
    }
    
    static func buildScene(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor) -> Scene {
        let scene = Scene()
        
        scene.ambientLightColor = SIMD3<Float>(0.01, 0.01, 0.01)
//        let light0 = Light(worldPosition: SIMD3<Float>( 0.5,  0, 2), color: SIMD3<Float>(1, 0, 0))
//        let light1 = Light(worldPosition: SIMD3<Float>(-0.5,  0, 2), color: SIMD3<Float>(0, 1, 0))
//        let light2 = Light(worldPosition: SIMD3<Float>( 0, -0.5, 2), color: SIMD3<Float>(0, 0, 1))
//        let light3 = Light(worldPosition: SIMD3<Float>( 0,  0.5, 2), color: SIMD3<Float>(1, 1, 1))
//        scene.lights = [ light0, light1, light2, light3 ]
        scene.pointLights = Scene.lightCircle(numLights: 64)
        scene.sunLights.append(SunLight(worldPosition: SIMD3<Float>(0, 0, 2)))
        
        let plane = Node.makePlane(device: device)
        plane.modelMatrix.scaleBy(s: 2)
        plane.modelMatrix.rotateAbout(axis: SIMD3<Float>(1,0,0), angleRadians: Float.pi/2)
//        let teapot = Node.makeTeapot(device: device, vertexDescriptor: vertexDescriptor)
        scene.rootNode.children.append(plane)
        return scene
    }
    
    static func buildVertexDescriptor() -> MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: MemoryLayout<Float>.size * 3,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[2] = MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate,
                                                            format: .float2,
                                                            offset: MemoryLayout<Float>.size * 6,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<Float>.size * 8)
        return vertexDescriptor
    }
    
    static func buildSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.normalizedCoordinates = true
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    static func buildDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        return device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
    }
    
    static func buildPipeline(device: MTLDevice, view: MTKView, vertexDescriptor: MDLVertexDescriptor) -> (MTLRenderPipelineState, MTLRenderPipelineReflection?) {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not load default library from main bundle")
        }
        
        let vertexFunction = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_hologram")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
                
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        Renderer.configAlphaBlend(pipelineDescriptor: pipelineDescriptor)

        let mtlVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor)
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        var pipelineReflection: MTLRenderPipelineReflection? = nil
        
        do {
            let pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor, options: [], reflection: &pipelineReflection)
            return (pipelineState, pipelineReflection)
        } catch {
            fatalError("Could not create render pipeline state object: \(error)")
        }
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
    
    func update(_ view: MTKView) {
        time += 1 / Float(view.preferredFramesPerSecond)
        
        scene.cameraWorldPosition = SIMD3<Float>(0, 0, 2)
        viewMatrix = float4x4(translationBy: -scene.cameraWorldPosition)
        
        let aspectRatio = Float(view.drawableSize.width / view.drawableSize.height)
        projectionMatrix = float4x4(perspectiveProjectionFov: Float.pi / 3, aspectRatio: aspectRatio, nearZ: 0.1, farZ: 100)
        
        let angle = Float(0) // -time / 2
//        scene.lights[0].worldPosition = SIMD3<Float>(0.5,  0, 2 + sin(time)*0.1)
        scene.frequency = Float(10*sin(time) + 300)
        scene.rootNode.modelMatrix = float4x4(rotationAbout: SIMD3<Float>(0, 1, 0), by: angle) *  float4x4(scaleBy: 1.5)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    func draw(in view: MTKView) {
        update(view)
        
        let pointLightSize = scene.pointLights.count * MemoryLayout<PointLight>.size
        let pointLightBuffer = device.makeBuffer(bytes: scene.pointLights, length: pointLightSize, options: [])
        
        let sunLightSize = scene.sunLights.count * MemoryLayout<SunLight>.size
        let sunLightBuffer = device.makeBuffer(bytes: scene.sunLights, length: sunLightSize, options: [])
        
        var sceneUniforms = SceneUniforms(numPointLights: Int32(scene.pointLights.count),
                                          numSunLights: Int32(scene.sunLights.count),
                                          frequency: scene.frequency,
                                          cameraWorldPosition: scene.cameraWorldPosition,
                                          ambientLightColor: scene.ambientLightColor)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        if let renderPassDescriptor = view.currentRenderPassDescriptor, let drawable = view.currentDrawable {
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            commandEncoder.setDepthStencilState(depthStencilState)
            commandEncoder.setRenderPipelineState(renderPipeline)
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
            commandEncoder.setFragmentBytes(&sceneUniforms, length: MemoryLayout<SceneUniforms>.size, index: 0)
            commandEncoder.setFragmentBuffer(pointLightBuffer, offset: 0, index: 2)
            commandEncoder.setFragmentBuffer(sunLightBuffer, offset: 0, index: 3)
            drawNodeRecursive(scene.rootNode, parentTransform: matrix_identity_float4x4, commandEncoder: commandEncoder)
            commandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    func drawNodeRecursive(_ node: Node, parentTransform: float4x4, commandEncoder: MTLRenderCommandEncoder) {
        let modelMatrix = parentTransform * node.modelMatrix
        
        if let mesh = node.mesh, let baseColorTexture = node.material.baseColorTexture {
            let viewProjectionMatrix = projectionMatrix * viewMatrix
            var vertexUniforms = VertexUniforms(viewProjectionMatrix: viewProjectionMatrix,
                                                modelMatrix: modelMatrix,
                                                normalMatrix: modelMatrix.normalMatrix)
            commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.size, index: 1)
            
            var nodeUniforms = NodeUniforms(specularColor: node.material.specularColor,
                                            specularPower: node.material.specularPower)
            commandEncoder.setFragmentBytes(&nodeUniforms, length: MemoryLayout<NodeUniforms>.size, index: 1)
            commandEncoder.setFragmentTexture(baseColorTexture, index: 0)

            let vertexBuffer = mesh.vertexBuffers.first!
            commandEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
            
            for submesh in mesh.submeshes {
                let indexBuffer = submesh.indexBuffer
                commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                     indexCount: submesh.indexCount,
                                                     indexType: submesh.indexType,
                                                     indexBuffer: indexBuffer.buffer,
                                                     indexBufferOffset: indexBuffer.offset)
            }
        }
        
        for child in node.children {
            drawNodeRecursive(child, parentTransform: modelMatrix, commandEncoder: commandEncoder)
        }
    }
}
