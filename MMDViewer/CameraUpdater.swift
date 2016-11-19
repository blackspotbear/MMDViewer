import Foundation
import CoreGraphics
import GLKit

class CameraUpdater: Updater {
    var viewMatrix = GLKMatrix4Identity
    var rot: GLKQuaternion
    var pos: GLKVector3

    init(rot: GLKQuaternion, pos: GLKVector3) {
        self.rot = rot
        self.pos = pos
    }

    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node) {
        viewMatrix = GLKMatrix4MakeWithQuaternion(GLKQuaternionInvert(rot)).multiply(
            GLKMatrix4MakeTranslation(-pos.x, -pos.y, -pos.z))
        var renderer = renderer
        renderer.viewMatrix = viewMatrix
    }
}
