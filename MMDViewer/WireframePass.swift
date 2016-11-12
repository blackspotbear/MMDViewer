import Foundation
import Metal

private let depthTextureSampleCount = 1

private func MakeDepthStencilState(_ device: MTLDevice) -> MTLDepthStencilState {
    let desc = MTLDepthStencilDescriptor()
    desc.isDepthWriteEnabled = true
    desc.depthCompareFunction = .lessEqual
    return device.makeDepthStencilState(descriptor: desc)
}

private func LoadShaderFunction(_ device: MTLDevice) -> MTLRenderPipelineDescriptor {
    guard let defaultLibrary = device.newDefaultLibrary() else {
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

    func begin(_ renderer: Renderer) {
        guard let colorBuffer = renderer.textureResources["ColorBuffer"] else {
            return
        }
        guard let depthBuffer = renderer.textureResources["DepthBuffer"] else {
            return
        }

        //
        // Update RenderPassDescriptor
        //
        if let colorAttachment = renderPassDescriptor.colorAttachments[0] {
            colorAttachment.texture = colorBuffer
            colorAttachment.loadAction = .load
            colorAttachment.storeAction = .store
        }

        if let attachment = renderPassDescriptor.depthAttachment {
            attachment.texture = depthBuffer
            attachment.loadAction = .load
            attachment.storeAction = .store
        }

        //
        // Update RenderPipelineState
        //
        var doUpdate = renderPipelineState == nil
        if renderPipelineDescriptor.colorAttachments[0].pixelFormat != colorBuffer.pixelFormat {
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = colorBuffer.pixelFormat
            doUpdate = true
        }
        if renderPipelineDescriptor.depthAttachmentPixelFormat != depthBuffer.pixelFormat {
            renderPipelineDescriptor.depthAttachmentPixelFormat = depthBuffer.pixelFormat
            doUpdate = true
        }
        if doUpdate {
            renderPipelineState = try! device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        }

        var renderer = renderer
        let encoder = renderer.commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        if let encoder = encoder {
            encoder.pushDebugGroup("wireframe pass")
            encoder.label = "wireframe buffer"
            encoder.setRenderPipelineState(renderPipelineState!)
            encoder.setDepthStencilState(depthStencilState)
            encoder.setCullMode(.none)
            encoder.setTriangleFillMode(.lines)
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
