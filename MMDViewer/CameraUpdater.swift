import Foundation
import CoreGraphics
import GLKit

class CameraUpdater: Updater {
    var viewMatrix = GLKMatrix4Identity
    var r: GLKVector3
    var x: GLKVector3

    init(rot: GLKVector3, pos: GLKVector3) {
        r = rot
        x = pos
    }

    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node) {
        var m = GLKMatrix4Multiply(GLKMatrix4MakeZRotation(-r.z), GLKMatrix4MakeXRotation(-r.x))
        m = GLKMatrix4Multiply(m, GLKMatrix4MakeYRotation(-r.y))
        m = GLKMatrix4Multiply(m, GLKMatrix4MakeTranslation(-x.x, -x.y, -x.z))

        self.viewMatrix = m
        var renderer = renderer
        renderer.viewMatrix = m
    }
}
