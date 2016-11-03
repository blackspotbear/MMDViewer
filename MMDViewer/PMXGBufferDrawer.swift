import Foundation
import Metal

private func MakeVertexDesc() -> MTLVertexDescriptor {
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

    return vertexDescriptor
}

private func MakeRenderPipelineState(device: MTLDevice, pixelFormatSpec: PixelFormatSpec) -> MTLRenderPipelineState {
    guard let defaultLibrary = device.newDefaultLibrary() else {
        fatalError("failed to create default library")
    }
    guard let vertexFunc = defaultLibrary.makeFunction(name: "gBufferVert") else {
        fatalError("failed to make vertex function")
    }
    guard let fragmentFunc = defaultLibrary.makeFunction(name: "gBufferFrag") else {
        fatalError("failed to make fragment function")
    }

    let vertexDescriptor = MakeVertexDesc()
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()

    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexFunc
    pipelineStateDescriptor.fragmentFunction = fragmentFunc

    for (i, e) in pixelFormatSpec.colorAttachmentFormats.enumerated() {
        pipelineStateDescriptor.colorAttachments[i].pixelFormat = e
    }
    pipelineStateDescriptor.depthAttachmentPixelFormat = pixelFormatSpec.depthPixelFormat
    pipelineStateDescriptor.stencilAttachmentPixelFormat = pixelFormatSpec.stencilPixelFormat

    do {
        return try device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    } catch {
        fatalError("failed to make render pipeline state")
    }
}

private func MakeDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
    let desc = MTLDepthStencilDescriptor()
    let stencilState = MTLStencilDescriptor()

    desc.isDepthWriteEnabled = true
    stencilState.stencilCompareFunction = .always
    stencilState.stencilFailureOperation = .keep
    stencilState.depthFailureOperation = .keep
    stencilState.depthStencilPassOperation = .replace
    stencilState.readMask = 0xFF
    stencilState.writeMask = 0xFF
    desc.depthCompareFunction = .lessEqual
    desc.frontFaceStencil = stencilState
    desc.backFaceStencil = stencilState

    return device.makeDepthStencilState(descriptor: desc)
}

class PMXGBufferDrawer: Drawer {
    let pmxObj: PMXObject
    let renderPipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState

    let shadowTexture: MTLTexture

    init(device: MTLDevice, pmxObj: PMXObject, pixelFormatSpec: PixelFormatSpec, shadowTexture: MTLTexture) {
        self.pmxObj = pmxObj
        renderPipelineState = MakeRenderPipelineState(device: device, pixelFormatSpec: pixelFormatSpec)
        self.shadowTexture = shadowTexture
        self.depthStencilState = MakeDepthStencilState(device: device)
    }

    func draw(_ renderer: Renderer) {
        guard let renderEncoder = renderer.renderCommandEncoder else {
            return
        }
        guard let currentVertexBuffer = pmxObj.currentVertexBuffer else {
            return
        }

        renderEncoder.setCullMode(.front)
        renderEncoder.setDepthStencilState(depthStencilState)

        renderEncoder.setVertexBuffer(currentVertexBuffer, offset: 0, at: 0)
        renderEncoder.setVertexBuffer(pmxObj.uniformBuffer, offset: 0, at: 1)
        renderEncoder.setVertexBuffer(pmxObj.matrixPalette, offset: 0, at: 2)

        renderEncoder.setFragmentBuffer(pmxObj.uniformBuffer, offset: 0, at:0)
        renderEncoder.setFragmentSamplerState(pmxObj.samplerState, at: 0)

        // draw primitives for each material
        var indexByteOffset = 0
        var materialByteOffset = 0
        var cntr = 0
        for material in pmxObj.pmx.materials {

            if cntr == pmxObj.pmx.materials.count - 3 {
                // NOTE: skip shadow object
            } else {
                let textureIndex = material.textureIndex != 255 ? material.textureIndex : 0
                let texture = pmxObj.textures[textureIndex]
                // use member variable 'renderPipelineState' instead
                // let renderPipelineState = texture.hasAlpha ? pmxObj.alphaPipelineState! : pmxObj.opaquePipelineState!

                renderEncoder.setRenderPipelineState(renderPipelineState)

                renderEncoder.setFragmentTexture(texture.texture, at: 0)
                renderEncoder.setFragmentTexture(shadowTexture, at: 1)

                renderEncoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: Int(material.vertexCount),
                    indexType: .uint16,
                    indexBuffer: pmxObj.indexBuffer,
                    indexBufferOffset: indexByteOffset)
            }
            cntr += 1

            indexByteOffset += Int(material.vertexCount) * 2 // 2 bytes per index
            materialByteOffset += MemoryLayout<ShaderMaterial>.stride
        }
    }
}
