//
//  Scene.swift
//  HologramShader
//
//  Created by qe on 4/18/22.
//

import MetalKit
import simd

struct Light {
    var worldPosition = SIMD3<Float>(0, 0, 0)
    var color = SIMD3<Float>(0, 0, 0)
}

class Material {
    var specularColor = SIMD3<Float>(1, 1, 1)
    var specularPower = Float(1)
    var baseColorTexture: MTLTexture?
}

class Node {
    var name: String
    weak var parent: Node?
    var children = [Node]()
    var modelMatrix = matrix_identity_float4x4
    var mesh: MTKMesh?
    var material = Material()
    
    init(name: String) {
        self.name = name
    }
    
    static func makePlane(device: MTLDevice) -> Node {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]
        
        let plane = Node(name: "Plane")
        let mesh = MDLMesh.newPlane(withDimensions: [0.5, 0.5], segments: [5, 5], geometryType: .triangles, allocator: bufferAllocator)
        plane.mesh = try? MTKMesh.init(mesh: mesh, device: device)
        plane.material.baseColorTexture = try? textureLoader.newTexture(name: "tiles_baseColor", scaleFactor: 1.0, bundle: nil, options: options)
        plane.material.specularPower = 200
        plane.material.specularColor = SIMD3<Float>(0.8, 0.8, 0.8)
        return plane
    }
    
    static func makeCube(device: MTLDevice) -> Node {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]
        
        let cube = Node(name: "Cube")
        let mesh = MDLMesh.newBox(withDimensions: [0.5, 0.5, 0.5], segments: [5, 5, 5], geometryType: .triangles, inwardNormals: false, allocator: bufferAllocator)
        cube.mesh = try? MTKMesh.init(mesh: mesh, device: device)
        cube.material.baseColorTexture = try? textureLoader.newTexture(name: "tiles_baseColor", scaleFactor: 1.0, bundle: nil, options: options)
        cube.material.specularPower = 200
        cube.material.specularColor = SIMD3<Float>(0.8, 0.8, 0.8)
        return cube
    }
    
    static func makeTeapot(device: MTLDevice, vertexDescriptor: MDLVertexDescriptor) -> Node {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [.generateMipmaps : true, .SRGB : true]

        let teapot = Node(name: "Teapot")

        let modelURL = Bundle.main.url(forResource: "teapot", withExtension: "obj")!
        let asset = MDLAsset(url: modelURL, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)
        teapot.mesh = try! MTKMesh.newMeshes(asset: asset, device: device).metalKitMeshes.first
        teapot.material.baseColorTexture = try? textureLoader.newTexture(name: "tiles_baseColor", scaleFactor: 1.0, bundle: nil, options: options)
        teapot.material.specularPower = 200
        teapot.material.specularColor = SIMD3<Float>(0.8, 0.8, 0.8)
        return teapot
    }
}

class Scene {
    var rootNode = Node(name: "Root")
    var ambientLightColor = SIMD3<Float>(0, 0, 0)
    var frequency = Float(200)
    var lights = [Light]()
    
    static func lightCircle(numLights: Int) -> [Light] {
        var lights: [Light] = []
        for i in 0...(numLights-1) {
            let angle = Float(i)/Float(numLights) * 2 * Float.pi
            let x: Float = cos(angle) * 0.5
            let y: Float = sin(angle) * 0.5
            lights.append(Light(worldPosition: SIMD3<Float>(x, y, 2), color: SIMD3<Float>(1, 1, 1)))
        }
        return lights
    }
    
    static func doubleSlit(numLights: Int) -> [Light] {
        var lights: [Light] = []
        for i in 0...numLights {
            let y = Float(i)/(Float(numLights) - 1.0) - 0.5
            lights.append(Light(worldPosition: SIMD3<Float>(-0.5, y, 2), color: SIMD3<Float>(1, 1, 1)))
            lights.append(Light(worldPosition: SIMD3<Float>( 0.5, y, 2), color: SIMD3<Float>(1, 1, 1)))
        }
        return lights
    }
}
