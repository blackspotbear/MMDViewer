import Foundation

private struct TraversalDrawState {
    let hasPass: Bool
    let hasModelMatrix: Bool
}

/// Node 木を update / draw の 2 段で巡回する。
/// 順序は renderer の状態管理と結びつくため、テストで固定した規約をここに集約する。
class Traverser {
    var renderer: Renderer

    init(renderer: Renderer) {
        self.renderer = renderer
    }

    /// 親ノードの updater を先に実行してから子へ降りる。
    /// ボーン姿勢やカメラ更新が子ノードの draw 準備に影響する前提を保つ。
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

    /// pass と model matrix stack を深さ優先で対応付けながら描画する。
    /// push / pop の対応が崩れると描画回帰しやすいため、変更時は回帰テストも更新する。
    private func drawCore(_ node: Node) {
        let drawState = beginNodeDraw(node)

        if let drawer = node.drawer {
            drawer.draw(renderer)
        }

        for node in node.children {
            drawCore(node)
        }

        endNodeDraw(node, state: drawState)
    }

    /// pass begin と model matrix push を、対応する cleanup 情報と一緒に返す。
    private func beginNodeDraw(_ node: Node) -> TraversalDrawState {
        if let pass = node.pass {
            pass.begin(renderer)
        }

        if let modelMatrix = node.modelMatrix {
            renderer.pushModelMatrix(modelMatrix)
        }

        return TraversalDrawState(
            hasPass: node.pass != nil,
            hasModelMatrix: node.modelMatrix != nil
        )
    }

    /// `beginNodeDraw` と対になる cleanup を 1 箇所へ集める。
    private func endNodeDraw(_ node: Node, state: TraversalDrawState) {
        if state.hasModelMatrix {
            renderer.popModelMatrix()
        }

        if state.hasPass, let pass = node.pass {
            pass.end(renderer)
        }
    }
}
