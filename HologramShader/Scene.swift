//
//  Scene.swift
//  HologramShader
//
//  Created by qe on 4/18/22.
//

import Foundation
import simd
import Metal
import MetalKit

struct Light {
    var worldPosition = SIMD3<Float>(0, 0, 0)
    var color = SIMD3<Float>(0, 0, 0)
};

class Material {
    var specularColor = SIMD3<Float>(1, 1, 1)
    var specularPower = Float(1)
    var baseColorTexture: MTLTexture?
};

class Node {
    var name: String
    weak var parent: Node?
    var children = [Node]()
    var modelMatrix = matrix_identity_float4x4
    var mesh = MTKMesh?
    var material = Material()
    
    init(name: String) {
        self.name = name
    }
}

class Scene {
    var rootNode = Node(name: "Root")
    var ambientLightColor = SIMD3<Float>(0, 0, 0)
    var lights = [Light]()
}
