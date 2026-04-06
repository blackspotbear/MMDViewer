import Foundation
import GLKit
import Metal

/// `melt` 基盤全体で共有する描画状態の窓口。
/// scene graph 側は concrete renderer を知らず、この protocol 越しに command buffer と行列状態へ触れる。
protocol Renderer {
    /// Traverser が node 深さに合わせて model matrix を積み下ろしする。
    func pushModelMatrix(_ mtrx: GLKMatrix4)
    @discardableResult func popModelMatrix() -> GLKMatrix4
    var modelMatrix: GLKMatrix4 { get set }

    var viewMatrix: GLKMatrix4 { get set }
    var projectionMatrix: GLKMatrix4 { get set }
    var textureResources: [String:MTLTexture] { get set }

    var commandBuffer: MTLCommandBuffer? { get set }
    var renderCommandEncoderStack: [MTLRenderCommandEncoder] { get set }
    var renderCommandEncoder: MTLRenderCommandEncoder? { get }

    /// 1 frame 分の GPU work の begin / end。
    func begin()
    func end()
    func reshape(_ bounds: CGRect)

    func setEndHandler(_: @escaping (Renderer) -> Void)
}
