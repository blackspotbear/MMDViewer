import Foundation
import CoreGraphics

class PMXUpdater: Updater {
    var playing = true
    var angularVelocity = CGPoint(x: 0, y: 0)
    let pmxObj: PMXObject

    init(pmxObj: PMXObject) {
        self.pmxObj = pmxObj
    }

    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node) {
        if dt > 0 {
            pmxObj.rotationX += Float(angularVelocity.y * CGFloat(dt))
            pmxObj.rotationY += Float(angularVelocity.x * CGFloat(dt))
            angularVelocity.x *= 0.95
            angularVelocity.y *= 0.95
        }

        if playing {
            pmxObj.updateCounter()
        }

        pmxObj.calc(renderer)
    }
}
