import Foundation
import Metal

private let depthTextureSampleCount = 1

// TODO: rename
private class MyPassResource {
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

    func renderPassDescriptorForDrawable(_ drawable: MTLTexture) -> MTLRenderPassDescriptor {

        // color attachment #0
        if let colorAttachment = renderPassDescriptor.colorAttachments[0] {
            colorAttachment.texture = drawable
            colorAttachment.loadAction = .clear
            colorAttachment.clearColor = MTLClearColorMake(0.0, 0.35, 0.65, 1.0)
            colorAttachment.storeAction = .store
        }

        // update depth texture
        var doUpdate = false
        if let tex = depthTex {
            doUpdate =
                (tex.width       != drawable.width)  ||
                (tex.height      != drawable.height) ||
                (tex.sampleCount != depthTextureSampleCount)
        } else {
            doUpdate = true
        }

        if doUpdate {
            let desc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .depth32Float,
                width: drawable.width,
                height: drawable.height,
                mipmapped: false)
            desc.textureType = (depthTextureSampleCount > 1) ? .type2DMultisample : .type2D
            desc.sampleCount = depthTextureSampleCount
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

        return renderPassDescriptor
    }
}

class PresentViewRenderPass: RenderPass {
    private let view: MetalView

    private let passRes: MyPassResource

    init(view: MetalView) {
        self.view = view
        passRes = MyPassResource(device: view.device!)
    }

    func begin(_ renderer: Renderer) {
        guard let drawable = view.currentDrawable else {
            return
        }
        guard let commandBuffer = renderer.commandBuffer else {
            return
        }

        let renderPassDescriptor = passRes.renderPassDescriptorForDrawable(drawable.texture)
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

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
