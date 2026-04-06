import Foundation

/// `melt` scene graph 上で、現在の renderer 状態を使って node を描画する責務。
/// buffer 更新は upstream の updater/object 側で済ませ、ここは draw call に集中させる。
protocol Drawer {
    func draw(_ renderer: Renderer)
}
