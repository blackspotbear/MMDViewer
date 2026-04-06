import Foundation
import GLKit

/// `melt` 層の scene graph を構成する最小ノード。
/// pass / updater / drawer / modelMatrix を疎結合に束ね、`Traverser` が順序規約を適用する。
class Node {
    var modelMatrix: GLKMatrix4?
    var children: [Node] = []
    var pass: RenderPass?
    var updater: Updater?
    var drawer: Drawer?
}
