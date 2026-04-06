import Foundation
import Metal

private func MakeDepthStencilState(_ device: MTLDevice) -> MTLDepthStencilState {
    let desc = MTLDepthStencilDescriptor()
    desc.isDepthWriteEnabled = true
    desc.depthCompareFunction = .lessEqual
    return device.makeDepthStencilState(descriptor: desc)!
}

private func LoadShaderFunction(_ device: MTLDevice) -> MTLRenderPipelineDescriptor {
    guard let defaultLibrary = device.makeDefaultLibrary() else {
        fatalError("failed to create default library")
    }
    guard let wireframeVert = defaultLibrary.makeFunction(name: "wireframeVert") else {
        fatalError("failed to make vertex function")
    }
    guard let wireframeFrag = defaultLibrary.makeFunction(name: "wireframeFrag") else {
        fatalError("failed to make fragment function")
    }

    let desc = MTLRenderPipelineDescriptor()
    desc.label = "Wireframe Render"
    desc.vertexFunction = wireframeVert
    desc.fragmentFunction = wireframeFrag

    return desc
}

class WireframePass: RenderPass {
    private struct BeginContext {
        let colorBuffer: MTLTexture
        let depthBuffer: MTLTexture
    }

    private let device: MTLDevice
    private var renderPipelineState: MTLRenderPipelineState?
    private var depthStencilState: MTLDepthStencilState
    private let renderPassDescriptor: MTLRenderPassDescriptor
    private let renderPipelineDescriptor: MTLRenderPipelineDescriptor

    init(device: MTLDevice) {
        self.device = device
        depthStencilState = MakeDepthStencilState(device)
        renderPassDescriptor = MTLRenderPassDescriptor()

        renderPipelineDescriptor = LoadShaderFunction(device)
    }

    private func beginContext(for renderer: Renderer) -> BeginContext? {
        guard let colorBuffer = renderer.textureResources["ColorBuffer"] else {
            return nil
        }
        guard let depthBuffer = renderer.textureResources["DepthBuffer"] else {
            return nil
        }

        return BeginContext(colorBuffer: colorBuffer, depthBuffer: depthBuffer)
    }

    private func updateRenderPassDescriptor(using context: BeginContext) {
        if let attachment = renderPassDescriptor.colorAttachments[0] {
            attachment.texture = context.colorBuffer
            attachment.loadAction = .load
            attachment.storeAction = .store
        }

        if let attachment = renderPassDescriptor.depthAttachment {
            attachment.texture = context.depthBuffer
            attachment.loadAction = .load
            attachment.storeAction = .store
        }
    }

    private func updateRenderPipelineState(using context: BeginContext) {
        var doUpdate = renderPipelineState == nil
        if renderPipelineDescriptor.colorAttachments[0].pixelFormat != context.colorBuffer.pixelFormat {
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = context.colorBuffer.pixelFormat
            doUpdate = true
        }
        if renderPipelineDescriptor.depthAttachmentPixelFormat != context.depthBuffer.pixelFormat {
            renderPipelineDescriptor.depthAttachmentPixelFormat = context.depthBuffer.pixelFormat
            doUpdate = true
        }
        if doUpdate {
            renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        }
    }

    private func configure(_ encoder: MTLRenderCommandEncoder) {
        encoder.pushDebugGroup("wireframe pass")
        encoder.label = "wireframe buffer"
        encoder.setRenderPipelineState(renderPipelineState!)
        encoder.setDepthStencilState(depthStencilState)
        encoder.setCullMode(.none)
        encoder.setTriangleFillMode(.lines)
    }

    func begin(_ renderer: Renderer) {
        guard let context = beginContext(for: renderer) else {
            return
        }

        updateRenderPassDescriptor(using: context)
        updateRenderPipelineState(using: context)

        let renderer = renderer
        let encoder = renderer.commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        if let encoder = encoder {
            configure(encoder)
            renderer.pushRenderCommandEncoder(encoder)
        }
    }

    func end(_ renderer: Renderer) {
        let renderer = renderer
        if let encoder = renderer.popRenderCommandEncoder() {
            encoder.popDebugGroup()
            encoder.endEncoding()
        }
    }
}
