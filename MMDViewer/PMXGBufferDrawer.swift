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

private func LoadShaderFunction(device: MTLDevice) -> MTLRenderPipelineDescriptor {
    guard let defaultLibrary = device.makeDefaultLibrary() else {
        fatalError("failed to create default library")
    }
    guard let vertexFunc = defaultLibrary.makeFunction(name: "gBufferVert") else {
        fatalError("failed to make vertex function")
    }
    guard let fragmentFunc = defaultLibrary.makeFunction(name: "gBufferFrag" /* "gBufferFragStipple" */) else {
        fatalError("failed to make fragment function")
    }

    let desc = MTLRenderPipelineDescriptor()
    desc.vertexDescriptor = MakeVertexDesc()
    desc.vertexFunction = vertexFunc
    desc.fragmentFunction = fragmentFunc

    return desc
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

    return device.makeDepthStencilState(descriptor: desc)!
}

private func UpdateRenderPipelineState(_ device: MTLDevice, _ renderer: Renderer, _ desc: MTLRenderPipelineDescriptor, _ renderPipelineState: MTLRenderPipelineState?) -> MTLRenderPipelineState? {

    guard let colorBuffer = renderer.textureResources["ColorBuffer"] else {
        return renderPipelineState
    }
    guard let normalBuffer = renderer.textureResources["NormalBuffer"] else {
        return renderPipelineState
    }
    guard let linearDBuffer = renderer.textureResources["LinearDBuffer"] else {
        return renderPipelineState
    }
    guard let lightBuffer = renderer.textureResources["LightBuffer"] else {
        return renderPipelineState
    }
    guard let depthBuffer = renderer.textureResources["DepthBuffer"] else {
        return renderPipelineState
    }
    guard let stencilBuffer = renderer.textureResources["StencilBuffer"] else {
        return renderPipelineState
    }

    var doUpdate = renderPipelineState == nil
    if desc.colorAttachments[0].pixelFormat != colorBuffer.pixelFormat {
        desc.colorAttachments[0].pixelFormat = colorBuffer.pixelFormat
        doUpdate = true
    }
    if desc.colorAttachments[1].pixelFormat != normalBuffer.pixelFormat {
        desc.colorAttachments[1].pixelFormat = normalBuffer.pixelFormat
        doUpdate = true
    }
    if desc.colorAttachments[2].pixelFormat != linearDBuffer.pixelFormat {
        desc.colorAttachments[2].pixelFormat = linearDBuffer.pixelFormat
        doUpdate = true
    }
    if desc.colorAttachments[3].pixelFormat != lightBuffer.pixelFormat {
        desc.colorAttachments[3].pixelFormat = lightBuffer.pixelFormat
        doUpdate = true
    }
    if desc.depthAttachmentPixelFormat != depthBuffer.pixelFormat {
        desc.depthAttachmentPixelFormat = depthBuffer.pixelFormat
        doUpdate = true
    }
    if desc.stencilAttachmentPixelFormat != stencilBuffer.pixelFormat {
        desc.stencilAttachmentPixelFormat = stencilBuffer.pixelFormat
        doUpdate = true
    }

    if doUpdate {
        return try! device.makeRenderPipelineState(descriptor: desc)
    } else {
        return renderPipelineState
    }
}

class PMXGBufferDrawer: Drawer {
    let device: MTLDevice
    let pmxObj: PMXObject
    var renderPipelineState: MTLRenderPipelineState?
    let depthStencilState: MTLDepthStencilState
    let renderPipelineDescriptor: MTLRenderPipelineDescriptor

    let shadowTexture: MTLTexture

    init(device: MTLDevice, pmxObj: PMXObject, shadowTexture: MTLTexture) {
        self.device = device
        self.pmxObj = pmxObj
        self.shadowTexture = shadowTexture
        renderPipelineDescriptor = LoadShaderFunction(device: device)
        depthStencilState = MakeDepthStencilState(device: device)
    }

    func draw(_ renderer: Renderer) {
        guard let renderEncoder = renderer.renderCommandEncoder else {
            return
        }
        guard let currentVertexBuffer = pmxObj.currentVertexBuffer else {
            return
        }

        renderPipelineState = UpdateRenderPipelineState(device, renderer, renderPipelineDescriptor, renderPipelineState)

        renderEncoder.setCullMode(.front)
        renderEncoder.setDepthStencilState(depthStencilState)

        renderEncoder.setVertexBuffer(currentVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(pmxObj.uniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(pmxObj.matrixPalette, offset: 0, index: 2)

        renderEncoder.setFragmentBuffer(pmxObj.uniformBuffer, offset: 0, index:0)
        renderEncoder.setFragmentSamplerState(pmxObj.samplerState, index: 0)

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

                renderEncoder.setRenderPipelineState(renderPipelineState!)

                renderEncoder.setFragmentTexture(texture.texture, index: 0)
                renderEncoder.setFragmentTexture(shadowTexture, index: 1)

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
