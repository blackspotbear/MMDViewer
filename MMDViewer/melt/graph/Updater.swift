import Foundation

/// `melt` scene graph 上で、draw 前に node 状態を更新する責務。
/// カメラ、アニメーション、オブジェクト更新などの時間依存処理をここへ載せる。
protocol Updater {
    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node)
}
