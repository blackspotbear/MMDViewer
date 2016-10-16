import Foundation

class Node {
    var children: [Node] = []
    var pass: RenderPass?
    var updater: Updater?
    var drawer: Drawer?
}
