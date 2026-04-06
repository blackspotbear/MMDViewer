import Foundation
import Metal

/// shadow map 用の最小 PMX drawer。
/// 色や material 設定は無視し、depth を書くために index 範囲だけを順に流す。
class PMXShadowDrawer: Drawer {
    let pmxObj: PMXObject

    init(pmxObj: PMXObject) {
        self.pmxObj = pmxObj
    }

    func draw(_ renderer: Renderer) {
        guard let renderEncoder = renderer.renderCommandEncoder else {
            return
        }
        guard let currentVertexBuffer = pmxObj.currentVertexBuffer else {
            return
        }

        renderEncoder.setVertexBuffer(currentVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(pmxObj.uniformBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(pmxObj.matrixPalette, offset: 0, index: 2)

        var indexByteOffset = 0
        for (index, material) in pmxObj.pmx.materials.enumerated() {
            if index == pmxObj.pmx.materials.count - 3 {
                // NOTE: skip shadow object
            } else {
                renderEncoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: Int(material.vertexCount),
                    indexType: .uint16,
                    indexBuffer: pmxObj.indexBuffer,
                    indexBufferOffset: indexByteOffset)
            }

            indexByteOffset += Int(material.vertexCount) * 2 // 2 bytes per index
        }
    }
}
