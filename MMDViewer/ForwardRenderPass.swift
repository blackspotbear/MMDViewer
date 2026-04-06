import Foundation
import Metal

private let depthTextureSampleCount = 1

/// `ForwardRenderPass` 専用の render target キャッシュ。
/// drawable サイズに追従する depth texture の再確保だけを担当する。
private class PassResource {
    let device: MTLDevice
    var depthTex: MTLTexture?

    private var renderPassDescriptor = MTLRenderPassDescriptor()

    init(device: MTLDevice) {
        self.device = device
    }

    func releaseTextures() {
        print("releasing textures...")
        depthTex = nil
        print("done")
    }

    private func configureColorAttachment(with drawable: MTLTexture) {
        if let colorAttachment = renderPassDescriptor.colorAttachments[0] {
            colorAttachment.texture = drawable
            colorAttachment.loadAction = .clear
            colorAttachment.clearColor = MTLClearColorMake(0.0, 0.35, 0.65, 1.0)
            colorAttachment.storeAction = .store
        }
    }

    private func needsDepthTextureUpdate(for drawable: MTLTexture) -> Bool {
        if let tex = depthTex {
            return
                (tex.width       != drawable.width)  ||
                (tex.height      != drawable.height) ||
                (tex.sampleCount != depthTextureSampleCount)
        }
        return true
    }

    private func configureDepthAttachment(with drawable: MTLTexture) {
        guard needsDepthTextureUpdate(for: drawable) else {
            return
        }

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: drawable.width,
            height: drawable.height,
            mipmapped: false)
        desc.textureType = (depthTextureSampleCount > 1) ? .type2DMultisample : .type2D
        desc.sampleCount = depthTextureSampleCount
        desc.usage = .renderTarget
        desc.storageMode = .private
        depthTex = device.makeTexture(descriptor: desc)

        if let depthTex = depthTex {
            print(String(format:"update depth texture (%d, %d)", depthTex.width, depthTex.height))

            if let attachment = renderPassDescriptor.depthAttachment {
                attachment.texture = depthTex
                attachment.loadAction = .clear
                attachment.storeAction = .dontCare
                attachment.clearDepth = 1.0
            }
        }
    }

    func renderPassDescriptorForDrawable(_ drawable: MTLTexture) -> MTLRenderPassDescriptor {
        configureColorAttachment(with: drawable)
        configureDepthAttachment(with: drawable)
        return renderPassDescriptor
    }
}

/// `melt` のもっとも基本的な forward pass。
/// view の drawable を描画先にし、単色背景と depth buffer を整えて scene 描画を始める。
class ForwardRenderPass: RenderPass {
    private let view: MetalView

    private let passRes: PassResource

    init(view: MetalView) {
        self.view = view
        passRes = PassResource(device: view.device!)
    }

    func begin(_ renderer: Renderer) {
        guard let drawable = view.currentDrawable else {
            return
        }
        guard drawable.texture.width > 0, drawable.texture.height > 0 else {
            view.releaseCurrentDrawable()
            return
        }
        guard let commandBuffer = renderer.commandBuffer else {
            return
        }

        let renderPassDescriptor = passRes.renderPassDescriptorForDrawable(drawable.texture)
        let renderEncoder = (commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor))!

        var renderer = renderer
        renderer.renderCommandEncoderStack.append(renderEncoder)
    }

    func end(_ renderer: Renderer) {
        var renderer = renderer
        if let renderEncoder = renderer.renderCommandEncoderStack.popLast() {
            renderEncoder.endEncoding()
        }
    }
}
