import Foundation
import Metal
import simd
import GLKit

private struct WireframeModelMatrices {
    var mvpMatrix: GLKMatrix4
}

private struct FloorModel {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int
}

private func MakeFloor(_ device: MTLDevice) -> FloorModel {
    let xsize: Float = 20
    let zsize: Float = 20
    let gridNum = 20
    let xstep = xsize / Float(gridNum)
    let zstep = zsize / Float(gridNum)

    var vdata = [GLKVector4]()
    for zi in 0...gridNum {
        for xi in 0...gridNum {
            let x = -xsize / 2 + Float(xi) * xstep
            let z = -zsize / 2 + Float(zi) * zstep
            let vtx = GLKVector4Make(x, 0, z, 1)
            vdata.append(vtx)
        }
    }

    var tindices = [Int16]()
    for zi in 0..<gridNum {
        for xi in 0..<gridNum {
            let lefttop = Int16((gridNum + 1) * zi + xi)
            tindices.append(lefttop)
            tindices.append(lefttop + (gridNum + 1))
            tindices.append(lefttop + 1)
            tindices.append(lefttop + 1)
            tindices.append(lefttop + (gridNum + 1))
            tindices.append(lefttop + (gridNum + 1) + 1)
        }
    }

    let vertexBuffer = device.makeBuffer(
        bytes: vdata,
        length: vdata.count * MemoryLayout<GLKVector4>.stride,
        options: [])
    vertexBuffer.label = "wireframe vertices"

    let indexBuffer = device.makeBuffer(
        bytes: tindices,
        length: tindices.count * MemoryLayout<Int16>.stride,
        options: [])
    indexBuffer.label = "wireframe indicies"

    let model = FloorModel(vertexBuffer: vertexBuffer, indexBuffer: indexBuffer, indexCount: tindices.count)

    return model
}

class WireFrameDrawer: Drawer {
    let matrixBufferProvider: BufferProvider

    private let model: FloorModel

    init(device: MTLDevice) {
        matrixBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<WireframeModelMatrices>.stride)
        model = MakeFloor(device)
    }

    func draw(_ renderer: Renderer) {
        guard let renderEncoder = renderer.renderCommandEncoder else {
            return
        }

        let matrixBuffer = matrixBufferProvider.nextBuffer()
        let matrixData = matrixBuffer.contents().bindMemory(
            to: WireframeModelMatrices.self,
            capacity: 1)
        var matrices = WireframeModelMatrices(
            mvpMatrix: renderer.projectionMatrix.multiply(renderer.viewMatrix))

        memcpy(matrixData, &matrices, MemoryLayout<WireframeModelMatrices>.size)

        renderEncoder.pushDebugGroup("wireframe")

        renderEncoder.setVertexBuffer(model.vertexBuffer, offset: 0, at: 0)
        renderEncoder.setVertexBuffer(matrixBuffer, offset: 0, at: 1)
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: model.indexCount,
            indexType: .uint16,
            indexBuffer: model.indexBuffer,
            indexBufferOffset: 0)

        renderEncoder.popDebugGroup()
    }
}
