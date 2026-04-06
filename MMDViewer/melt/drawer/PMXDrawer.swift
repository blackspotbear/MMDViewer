import Foundation
import Metal
import simd

/// forward path の PMX 描画で使う pipeline をまとめて構築する。
/// 透過/不透明だけを切り替え、material ごとの draw loop 自体は `PMXDrawer` に任せる。
private func CreateOpaquePipelinesState(_ device: MTLDevice, _ vertexDescriptor: MTLVertexDescriptor, _ vertexFunc: MTLFunction, _ fragmentFunc: MTLFunction) -> MTLRenderPipelineState {
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()

    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexFunc
    pipelineStateDescriptor.fragmentFunction = fragmentFunc
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float

    do {
        return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
        fatalError("failed to make render pipeline state")
    }
}

private func CreateAlphaPipelinesState(_ device: MTLDevice, _ vertexDescriptor: MTLVertexDescriptor, _ vertexFunc: MTLFunction, _ fragmentFunc: MTLFunction) -> MTLRenderPipelineState {
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()

    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexFunc
    pipelineStateDescriptor.fragmentFunction = fragmentFunc
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineStateDescriptor.depthAttachmentPixelFormat = .depth32Float

    if let ca = pipelineStateDescriptor.colorAttachments[0] {
        ca.isBlendingEnabled = true
        ca.rgbBlendOperation = .add
        ca.alphaBlendOperation = .add
        ca.sourceRGBBlendFactor = .one // expect image is PremultipliedLast
        ca.sourceAlphaBlendFactor = .one
        ca.destinationRGBBlendFactor = .oneMinusSourceAlpha
        ca.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }

    do {
        return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
        fatalError("failed to make render pipeline state")
    }
}

private func MakePipelineStates(_ device: MTLDevice) -> (MTLRenderPipelineState, MTLRenderPipelineState) {
    guard let defaultLibrary = device.makeDefaultLibrary() else {
        fatalError("failed to create default library")
    }
    guard let newVertexFunction = defaultLibrary.makeFunction(name: "basic_vertex") else {
        fatalError("failed to make vertex function")
    }
    guard let newFragmentFunction = defaultLibrary.makeFunction(name: "basic_fragment") else {
        fatalError("failed to make fragment function")
    }

    // Define vertex layout
    let vertexDescriptor = MTLVertexDescriptor()
    // position
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].format = .float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    // normal
    vertexDescriptor.attributes[1].offset = MemoryLayout<Float32>.size * 3
    vertexDescriptor.attributes[1].format = .float3
    vertexDescriptor.attributes[1].bufferIndex = 0
    // uv
    vertexDescriptor.attributes[2].offset = MemoryLayout<Float32>.size * 6
    vertexDescriptor.attributes[2].format = .float2
    vertexDescriptor.attributes[2].bufferIndex = 0
    // weight
    vertexDescriptor.attributes[3].offset = MemoryLayout<Float32>.size * 8
    vertexDescriptor.attributes[3].format = .float4
    vertexDescriptor.attributes[3].bufferIndex = 0
    // indices
    vertexDescriptor.attributes[4].offset = MemoryLayout<Float32>.size * 12
    vertexDescriptor.attributes[4].format = .short4
    vertexDescriptor.attributes[4].bufferIndex = 0
    // layout
    vertexDescriptor.layouts[0].stepFunction = .perVertex

    // an error occurred:
    // Expression was too complex to be solved in reasonable time;
    // consider breaking up the expression into distinct sub-expressions
    //
    //vertexDescriptor.layouts[0].stride = (MemoryLayout<Float32>.size) * (3 + 3 + 2 + 4 + 4/2)
    let sizeOfFloat32 = MemoryLayout<Float32>.size
    vertexDescriptor.layouts[0].stride = sizeOfFloat32 * (3 + 3 + 2 + 4 + 4/2)

    let opaquePipelineState = CreateOpaquePipelinesState(device, vertexDescriptor, newVertexFunction, newFragmentFunction)
    let alphaPipelineState = CreateAlphaPipelinesState(device, vertexDescriptor, newVertexFunction, newFragmentFunction)

    return (opaquePipelineState, alphaPipelineState)
}

class PMXDrawer: Drawer {
    let pmxObj: PMXObject

    var opaquePipelineState: MTLRenderPipelineState
    var alphaPipelineState: MTLRenderPipelineState

    init(pmxObj: PMXObject, device: MTLDevice) {
        self.pmxObj = pmxObj
        (opaquePipelineState, alphaPipelineState) = MakePipelineStates(device)
    }

    private func textureIndex(for material: Material) -> Int {
        return material.textureIndex != 255 ? material.textureIndex : 0
    }

    private func makeShaderMaterial(from material: Material) -> ShaderMaterial {
        return ShaderMaterial(
            ambientColor: SIMD3(material.ambient.r, material.ambient.g, material.ambient.b),
            diffuseColor: SIMD3(material.diffuse.r, material.diffuse.g, material.diffuse.b),
            specularColor: SIMD3(material.specular.r, material.specular.g, material.specular.b),
            specularPower: material.specularPower
        )
    }

    /// material ごとの texture / pipeline / fragment material 差し替えを 1 箇所へ集約する。
    private func encodeMaterial(_ material: Material,
                                indexByteOffset: Int,
                                renderEncoder: MTLRenderCommandEncoder) {
        let texture = pmxObj.textures[textureIndex(for: material)]
        let renderPipelineState = texture.hasAlpha ? alphaPipelineState : opaquePipelineState
        var shaderMaterial = makeShaderMaterial(from: material)

        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setFragmentTexture(texture.texture, index: 0)
        renderEncoder.setFragmentBytes(&shaderMaterial, length: MemoryLayout<ShaderMaterial>.stride, index: 1)

        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: Int(material.vertexCount),
            indexType: .uint16,
            indexBuffer: pmxObj.indexBuffer,
            indexBufferOffset: indexByteOffset)
    }

    func draw(_ renderer: Renderer) {
        guard let renderEncoder = renderer.renderCommandEncoder else {
            return
        }
        guard let currentVertexBuffer = pmxObj.currentVertexBuffer else {
            return
        }

        renderEncoder.setCullMode(.front)
        renderEncoder.setDepthStencilState(pmxObj.depthStencilState)

        renderEncoder.setVertexBuffer(currentVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(pmxObj.uniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(pmxObj.matrixPalette, offset: 0, index: 2)

        renderEncoder.setFragmentBuffer(pmxObj.uniformBuffer, offset: 0, index:0)
        renderEncoder.setFragmentSamplerState(pmxObj.samplerState, index: 0)

        // material ごとに texture / pipeline を切り替える forward path の本体。
        var indexByteOffset = 0
        for material in pmxObj.pmx.materials {
            encodeMaterial(material, indexByteOffset: indexByteOffset, renderEncoder: renderEncoder)
            indexByteOffset += Int(material.vertexCount) * 2 // 2 bytes per index
        }
    }
}
