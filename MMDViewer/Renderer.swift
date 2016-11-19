import Foundation
import GLKit
import Metal

protocol Renderer {
    var viewMatrix: GLKMatrix4 { get set }
    var projectionMatrix: GLKMatrix4 { get set }
    var textureResources: [String:MTLTexture] { get set }

    var commandBuffer: MTLCommandBuffer? { get set }
    var renderCommandEncoderStack: [MTLRenderCommandEncoder] { get set }
    var renderCommandEncoder: MTLRenderCommandEncoder? { get }

    func pushCameraMatrix(_ mtrx: GLKMatrix4)
    func popCameraMatrix() -> GLKMatrix4
    var currentCameraMatrix: GLKMatrix4 { get set }

    func begin()
    func end()
    func reshape(_ bounds: CGRect)

    func setEndHandler(_: @escaping (Renderer) -> Void)
}
