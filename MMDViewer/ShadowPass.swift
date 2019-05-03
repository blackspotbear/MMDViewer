import Foundation
import Metal

private func MakeFunctionFromLibrary(_ library: MTLLibrary, name: String) -> MTLFunction {
    let fn = library.makeFunction(name: name)
    if fn == nil {
        fatalError(String(format: "faled to load function %s", name))
    }
    return fn!
}

private func MakeDepthStencilState(_ device: MTLDevice) -> MTLDepthStencilState {
    let desc = MTLDepthStencilDescriptor()
    desc.isDepthWriteEnabled = true
    desc.depthCompareFunction = .lessEqual
    return device.makeDepthStencilState(descriptor: desc)!
}

class ShadowPass: RenderPass {
    var shadowTexture: MTLTexture // render target

    private var shadowRenderPassDescriptor: MTLRenderPassDescriptor
    private var renderPipelineState: MTLRenderPipelineState
    private var shadowDepthStencilState: MTLDepthStencilState

    init(device: MTLDevice) {
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            fatalError("failed to create a default library")
        }

        let shadowTextureDesc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: 1024,
            height: 1024,
            mipmapped: false)
        shadowTextureDesc.usage = [.renderTarget, .shaderRead]
        shadowTexture = device.makeTexture(descriptor: shadowTextureDesc)!
        shadowTexture.label = "shadow map"

        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Shadow Render"
        desc.vertexFunction = MakeFunctionFromLibrary(defaultLibrary, name: "depthVertex")
        desc.fragmentFunction = nil
        desc.depthAttachmentPixelFormat = shadowTexture.pixelFormat
        try! renderPipelineState = device.makeRenderPipelineState(descriptor: desc)

        shadowRenderPassDescriptor = MTLRenderPassDescriptor()
        if let attachment = shadowRenderPassDescriptor.depthAttachment {
            attachment.texture = shadowTexture
            attachment.loadAction = .clear
            attachment.storeAction = .store
            attachment.clearDepth = 1.0
        }

        shadowDepthStencilState = MakeDepthStencilState(device)
    }

    func begin(_ renderer: Renderer) {
        var renderer = renderer

        let encoder = renderer.commandBuffer?.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor)
        if let encoder = encoder {
            encoder.pushDebugGroup("shadow buffer pass")
            encoder.label = "shadow buffer"
            encoder.setRenderPipelineState(renderPipelineState)
            encoder.setDepthStencilState(shadowDepthStencilState)
            encoder.setCullMode(.front)
            encoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)

            renderer.renderCommandEncoderStack.append(encoder)
        }
    }

    func end(_ renderer: Renderer) {
        var renderer = renderer

        if let encoder = renderer.renderCommandEncoderStack.popLast() {
            encoder.popDebugGroup()
            encoder.endEncoding()
        }
    }
}
