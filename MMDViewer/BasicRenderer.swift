import Foundation
import GLKit
import Metal

private let kInFlightCommandBuffers = 3
private let defaultFieldOfViewRadians = 85.0 * .pi / 180.0

/// アプリ全体で共有する renderer の最小実装。
/// command buffer と行列状態をまとめて持ち、各 pass / drawer はここを介して GPU へ書き込む。
class BasicRenderer: Renderer {
    private var modelMatrixStack = [GLKMatrix4](repeating: GLKMatrix4Identity, count: 1)

    /// Node traversal に合わせて model matrix を積む。
    /// 現状は「上書き」ではなく「push された matrix をそのまま top に置く」規約を採っている。
    func pushModelMatrix(_ mtrx: GLKMatrix4) {
        modelMatrixStack.append(mtrx)
    }

    func popModelMatrix() -> GLKMatrix4 {
        return modelMatrixStack.popLast()!
    }
    
    var modelMatrix: GLKMatrix4 {
        get {
            return modelMatrixStack[modelMatrixStack.index(before: modelMatrixStack.endIndex)]
        }
        set (value) {
            modelMatrixStack[modelMatrixStack.index(before: modelMatrixStack.endIndex)] = value
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
        updateProjectionMatrix(aspect: 1.0)
    }

    /// 1 frame 分の command buffer を確保する。
    /// in-flight 数を制限して古い Metal 実装と現代 simulator の両方で過剰な先行発行を避ける。
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

    /// viewport 変化時だけ投影行列を更新し、初回レイアウトや回転時の無駄な再計算を避ける。
    func reshape(_ bounds: CGRect) {
        let viewportSize = bounds.integral.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }
        guard viewportSize != lastViewportSize else { return }

        lastViewportSize = viewportSize

        let aspect = Float(viewportSize.width / viewportSize.height)
        updateProjectionMatrix(aspect: aspect)
    }

    func setEndHandler(_ handler: @escaping (Renderer) -> Void) {
        self.onEndHandler = handler
    }

    /// renderer 全体で共有する透視投影の既定値を 1 箇所に集める。
    private func updateProjectionMatrix(aspect: Float) {
        projectionMatrix = GLKMatrix4.perspective(
            fovyRadians: Float(defaultFieldOfViewRadians),
            aspect: aspect,
            near: 0.01,
            far: 100.0
        )
    }
}
