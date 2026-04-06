import Foundation
import CoreGraphics

/// `PMXObject` 1 体分の毎フレーム更新を束ねる updater。
/// 入力由来の回転、再生中フレーム更新、姿勢/物理/描画バッファ計算をこの順に進める。
class PMXUpdater: Updater {
    var playing = true
    var angularVelocity = CGPoint(x: 0, y: 0)
    let pmxObj: PMXObject

    init(pmxObj: PMXObject) {
        self.pmxObj = pmxObj
    }

    private func applyAngularVelocityDecay(_ dt: CFTimeInterval) {
        if dt > 0 {
            pmxObj.rotationX += Float(angularVelocity.y * CGFloat(dt))
            pmxObj.rotationY += Float(angularVelocity.x * CGFloat(dt))
            angularVelocity.x *= 0.95
            angularVelocity.y *= 0.95
        }
    }

    private func advanceAnimationFrameIfNeeded() {
        if playing {
            pmxObj.updateCounter()
        }
    }

    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node) {
        // フリック由来の角速度だけは updater 側で減衰させ、
        // PMXObject 本体は「現在の rotation が与えられる」前提を保つ。
        applyAngularVelocityDecay(dt)
        advanceAnimationFrameIfNeeded()

        // frame counter が確定してから 1 frame 分の姿勢・物理・buffer 更新をまとめて流す。
        pmxObj.calc(renderer)
    }
}
