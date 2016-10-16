import Foundation

protocol RenderPass {
    func begin(_ renderer: Renderer)
    func end(_ renderer: Renderer)
}
