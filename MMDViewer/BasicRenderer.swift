import Foundation
import GLKit
import Metal

private let kInFlightCommandBuffers = 3

class BasicRenderer: Renderer {
    var viewMatrix = GLKMatrix4Identity
    var projectionMatrix = GLKMatrix4Identity

    var textureResources = [String:MTLTexture]()

    var commandBuffer: MTLCommandBuffer?
    var renderCommandEncoderStack: [MTLRenderCommandEncoder] = []
    var renderCommandEncoder: MTLRenderCommandEncoder? {
        return renderCommandEncoderStack.last
    }

    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var shaderLibrary: MTLLibrary?

    private let inflightSemaphore: DispatchSemaphore
    private var mnOrientation = UIInterfaceOrientation.unknown

    private var onEndHandler: ((Renderer) -> Void)?

    init() {
        inflightSemaphore = DispatchSemaphore(value: kInFlightCommandBuffers)
    }

    func configure(_ device: MTLDevice) {
        guard let defaultLibrary = device.newDefaultLibrary() else {
            fatalError("failed to create a default library")
        }

        shaderLibrary = defaultLibrary
        self.device = device
        commandQueue = device.makeCommandQueue()

        viewMatrix = GLKMatrix4MakeLookAt(0, 10, 20, 0, 10, 0, 0, 1, 0)
        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(85.0), 1.0, 0.01, 100.0)
    }

    func begin() {
        _ = inflightSemaphore.wait(timeout: DispatchTime.distantFuture)

        commandBuffer = commandQueue!.makeCommandBuffer()
        commandBuffer!.addCompletedHandler { (commandBuffer) -> Void in
            self.inflightSemaphore.signal()
        }
    }

    func end() {
        if let onEndHandler = onEndHandler {
            onEndHandler(self)
        }
        commandBuffer = nil
    }

    func reshape(_ bounds: CGRect) {
        let orientation = UIApplication.shared.statusBarOrientation

        if mnOrientation != orientation {
            mnOrientation = orientation
            let aspect = Float(bounds.size.width / bounds.size.height)
            projectionMatrix = GLKMatrix4MakePerspective(
                GLKMathDegreesToRadians(85.0),
                aspect,
                0.01,
                100.0)
        }
    }

    func setEndHandler(_ handler: @escaping (Renderer) -> Void) {
        self.onEndHandler = handler
    }
}
