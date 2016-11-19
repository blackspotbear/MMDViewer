import Foundation
import GLKit

class Node {
    var modelMatrix: GLKMatrix4?
    var children: [Node] = []
    var pass: RenderPass?
    var updater: Updater?
    var drawer: Drawer?
}
