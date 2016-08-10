import Foundation
import Metal

class PresentViewRenderPass: RenderPass {
    private let view: MetalView

    init(view: MetalView) {
        self.view = view
        view.pixelFormatSpec.colorAttachmentFormats[0] = .bgra8Unorm
        view.pixelFormatSpec.clearColors[0] = MTLClearColorMake(0.0, 0.35, 0.65, 1.0)
        view.pixelFormatSpec.depthPixelFormat = .depth32Float
    }

    func begin(_ renderer: Renderer) {
        var renderer = renderer
        if let renderPassDescriptor = view.renderPassDescriptor {
            if let commandBuffer = renderer.commandBuffer {
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
                renderer.renderCommandEncoderStack.append(renderEncoder)
            }
        }
    }

    func end(_ renderer: Renderer) {
        var renderer = renderer
        if let drawable = view.currentDrawable {
            if let renderEncoder = renderer.renderCommandEncoderStack.popLast() {
                renderEncoder.endEncoding()
                if let commandBuffer = renderer.commandBuffer {
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
                view.releaseCurrentDrawable()
            }
        }
    }
}
