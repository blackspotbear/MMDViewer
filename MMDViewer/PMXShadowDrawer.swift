import Foundation
import Metal

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

        renderEncoder.setVertexBuffer(currentVertexBuffer, offset: 0, at: 0)
        renderEncoder.setVertexBuffer(pmxObj.uniformBuffer, offset: 0, at: 1)
        renderEncoder.setVertexBuffer(pmxObj.matrixPalette, offset: 0, at: 2)

        var indexByteOffset = 0
        var materialByteOffset = 0
        for material in pmxObj.pmx.materials {
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: Int(material.vertexCount),
                indexType: .uint16,
                indexBuffer: pmxObj.indexBuffer,
                indexBufferOffset: indexByteOffset)

            indexByteOffset += Int(material.vertexCount) * 2 // 2 bytes per index
            materialByteOffset += MemoryLayout<ShaderMaterial>.stride
        }
    }
}
