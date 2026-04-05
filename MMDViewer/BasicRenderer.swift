import Foundation
import GLKit
import Metal

private let kInFlightCommandBuffers = 3

class BasicRenderer: Renderer {
    private var modelMatrixStack = [GLKMatrix4](repeating: GLKMatrix4Identity, count: 1)

    func pushModelMatrix(_ mtrx: GLKMatrix4) {
        modelMatrixStack.append(mtrx)
    }

    func popModelMatrix() -> GLKMatrix4 {
        return modelMatrixStack.popLast()!
    }
    
    var modelMatrix: GLKMatrix4 {
        get {
            return modelMatrixStack[modelMatrixStack.endIndex]
        }
        set (value) {
            modelMatrixStack[modelMatrixStack.endIndex] = value
        }
    }

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
    private var lastViewportSize = CGSize.zero

    private var onEndHandler: ((Renderer) -> Void)?

    init() {
        inflightSemaphore = DispatchSemaphore(value: kInFlightCommandBuffers)
    }

    func configure(_ device: MTLDevice) {
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            fatalError("failed to create a default library")
        }

        shaderLibrary = defaultLibrary
        self.device = device
        commandQueue = device.makeCommandQueue()

        viewMatrix = GLKMatrix4.lookAt(
            eye: GLKVector3Make(0, 10, 20),
            center: GLKVector3Make(0, 10, 0),
            up: GLKVector3Make(0, 1, 0)
        )
        projectionMatrix = GLKMatrix4.perspective(
            fovyRadians: GLKMathDegreesToRadians(85.0),
            aspect: 1.0,
            near: 0.01,
            far: 100.0
        )
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
        let viewportSize = bounds.integral.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }
        guard viewportSize != lastViewportSize else { return }

        lastViewportSize = viewportSize

        let aspect = Float(viewportSize.width / viewportSize.height)
        projectionMatrix = GLKMatrix4.perspective(
            fovyRadians: GLKMathDegreesToRadians(85.0),
            aspect: aspect,
            near: 0.01,
            far: 100.0
        )
    }

    func setEndHandler(_ handler: @escaping (Renderer) -> Void) {
        self.onEndHandler = handler
    }
}
