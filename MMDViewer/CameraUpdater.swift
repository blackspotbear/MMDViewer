import Foundation
import CoreGraphics
import GLKit

/// 入力ジェスチャで更新された camera 状態を renderer の view matrix へ反映する updater。
/// `MMDView` 側は `rot` / `pos` を触るだけにして、view 行列の組み立てはここへ閉じ込める。
class CameraUpdater: Updater {
    var viewMatrix = GLKMatrix4Identity
    var rot: GLKQuaternion
    var pos: GLKVector3

    init(rot: GLKQuaternion, pos: GLKVector3) {
        self.rot = rot
        self.pos = pos
    }

    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node) {
        // camera transform は world 行列の逆なので、回転の逆を先に適用してから平行移動を積む。
        viewMatrix = GLKMatrix4.rotation(rot.inverse()).multiply(
            GLKMatrix4.translation(-pos.x, -pos.y, -pos.z))
        var renderer = renderer
        renderer.viewMatrix = viewMatrix
    }
}
