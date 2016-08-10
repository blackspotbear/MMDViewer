import Foundation

class Traverser {
    var renderer: Renderer

    init(renderer: Renderer) {
        self.renderer = renderer
    }

    func update(_ dt: CFTimeInterval, node: Node) {
        if let updater = node.updater {
            updater.update(dt, renderer: renderer, node: node)
        }

        for node in node.children {
            update(dt, node: node)
        }
    }

    func draw(_ node: Node) {
        autoreleasepool {
            renderer.begin()
            drawCore(node)
            renderer.end()
        }
    }

    private func drawCore(_ node: Node) {
        if let pass = node.pass {
            pass.begin(renderer)
        }

        if let drawer = node.drawer {
            drawer.draw(renderer)
        }

        for node in node.children {
            drawCore(node)
        }

        if let pass = node.pass {
            pass.end(renderer)
        }
    }
}
