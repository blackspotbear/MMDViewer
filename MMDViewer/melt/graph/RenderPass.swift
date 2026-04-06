import Foundation

/// `melt` 基盤で command encoder の begin / end を 1 組として扱う責務。
/// shadow や g-buffer など pass ごとの描画状態切り替えはここへ集約する。
protocol RenderPass {
    func begin(_ renderer: Renderer)
    func end(_ renderer: Renderer)
}
