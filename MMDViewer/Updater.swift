import Foundation

protocol Updater {
    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node)
}
