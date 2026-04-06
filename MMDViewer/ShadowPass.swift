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

/// `melt` の shadow map 生成 pass。
/// depth のみを書き出して、後段の forward / deferred lighting から shaderRead で参照される。
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
        shadowTextureDesc.storageMode = .private
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

    private func makeRenderEncoder(with renderer: Renderer) -> MTLRenderCommandEncoder? {
        return renderer.commandBuffer?.makeRenderCommandEncoder(descriptor: shadowRenderPassDescriptor)
    }

    private func configure(_ encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("shadow buffer pass")
        encoder.label = "shadow buffer"
        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setDepthStencilState(shadowDepthStencilState)
        encoder.setCullMode(.front)
        encoder.setDepthBias(0.01, slopeScale: 1.0, clamp: 0.01)
    }

    func begin(_ renderer: Renderer) {
        var renderer = renderer

        if let encoder = makeRenderEncoder(with: renderer) {
            configure(encoder)
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
