import Foundation
import Metal
import simd
import GLKit

private struct LightModelMatrices {
    var mvpMatrix: GLKMatrix4
    var mvMatrix: GLKMatrix4
}

private struct LightFragmentInputs {
    let lightPosition: GLKVector4
    var viewLightPosition: GLKVector4
    let lightColorRadius: GLKVector4
}

private let inscribe = Float(0.755761314076171) // sqrtf(3.0) / 12.0 * (3.0 + sqrtf(5.0))
private let circumscribe = Float(0.951056516295154) // 0.25 * sqrtf(10.0 + 2.0 * sqrtf(5.0))

private func MakeIcosahedron(_ device: MTLDevice) -> (MTLBuffer, MTLBuffer) {
    let X = Float(0.5 / inscribe)
    let Z = X * (1 + sqrtf(5)) / 2
    let lightVdata = [
        GLKVector4( -X, 0.0,   Z, 1.0),
        GLKVector4(  X, 0.0,   Z, 1.0),
        GLKVector4( -X, 0.0,  -Z, 1.0),
        GLKVector4(  X, 0.0,  -Z, 1.0),
        GLKVector4(0.0,   Z,   X, 1.0),
        GLKVector4(0.0,   Z,  -X, 1.0),
        GLKVector4(0.0,  -Z,   X, 1.0),
        GLKVector4(0.0,  -Z,  -X, 1.0),
        GLKVector4(  Z,   X, 0.0, 1.0),
        GLKVector4( -Z,   X, 0.0, 1.0),
        GLKVector4(  Z,  -X, 0.0, 1.0),
        GLKVector4( -Z,  -X, 0.0, 1.0)
    ]

    let tindices: [Int16] = [
        0, 1,  4,
        0, 4,  9,
        9, 4,  5,
        4, 8,  5,
        4, 1,  8,
        8, 1, 10,
        8, 10, 3,
        5, 8,  3,
        5, 3,  2,
        2, 3,  7,
        7, 3, 10,
        7, 10, 6,
        7, 6, 11,
        11, 6,  0,
        0, 6,  1,
        6, 10, 1,
        9, 11, 0,
        9, 2, 11,
        9, 5,  2,
        7, 11, 2
    ]

    let vertexBuffer = device.makeBuffer(
        bytes: lightVdata, length: lightVdata.count * MemoryLayout<GLKVector4>.stride, options: [])
    vertexBuffer.label = "light model vertices"

    let indexBuffer = device.makeBuffer(
        bytes: tindices, length: tindices.count * MemoryLayout<Int16>.stride, options: [])
    indexBuffer.label = "light model indicies"

    return (vertexBuffer, indexBuffer)
}

private func MakeRenderPipelineState(_ device: MTLDevice, _ pixelFormatSpec: PixelFormatSpec) -> (MTLRenderPipelineState, MTLRenderPipelineState) {
    guard let defaultLibrary = device.newDefaultLibrary() else {
        fatalError("failed to create default library")
    }
    guard let lightVert = defaultLibrary.makeFunction(name: "lightVert") else {
        fatalError("failed to make vertex function")
    }
    guard let lightFrag = defaultLibrary.makeFunction(name: "lightFrag") else {
        fatalError("failed to make fragment function")
    }

    let desc = MTLRenderPipelineDescriptor()

    for i in 0...3 {
        desc.colorAttachments[i].pixelFormat = pixelFormatSpec.colorAttachmentFormats[i]
    }
    desc.depthAttachmentPixelFormat = pixelFormatSpec.depthPixelFormat
    desc.stencilAttachmentPixelFormat = pixelFormatSpec.stencilPixelFormat

    desc.label = "Light Mask Render"
    desc.vertexFunction = lightVert
    desc.fragmentFunction = nil
    for i in 0...3 {
        desc.colorAttachments[i].writeMask = [] // means '.none'
    }

    let lightMaskPipeline = try! device.makeRenderPipelineState(descriptor: desc)

    desc.label = "Light Color Render"
    desc.vertexFunction = lightVert
    desc.fragmentFunction = lightFrag
    for i in 0...3 {
        desc.colorAttachments[i].writeMask = .all
    }
    let lightColorPipeline = try! device.makeRenderPipelineState(descriptor: desc)

    return (lightMaskPipeline, lightColorPipeline)

}

private func MakeLightMaskStencilState(_ device: MTLDevice) -> MTLDepthStencilState {
    let desc = MTLDepthStencilDescriptor()
    let stencilState = MTLStencilDescriptor()

    desc.isDepthWriteEnabled = false
    stencilState.stencilCompareFunction = .equal
    stencilState.stencilFailureOperation = .keep
    stencilState.depthFailureOperation = .incrementClamp
    stencilState.depthStencilPassOperation = .keep
    stencilState.readMask = 0xFF
    stencilState.writeMask = 0xFF
    desc.depthCompareFunction = .greaterEqual // .lessEqual
    desc.frontFaceStencil = stencilState
    desc.backFaceStencil = stencilState

    return device.makeDepthStencilState(descriptor: desc)
}

private func MakeLightColorStencilState(_ device: MTLDevice) -> (MTLDepthStencilState, MTLDepthStencilState) {
    let desc = MTLDepthStencilDescriptor()
    let stencilState = MTLStencilDescriptor()
    desc.isDepthWriteEnabled = false
    stencilState.stencilCompareFunction = .less
    stencilState.stencilFailureOperation = .keep
    stencilState.depthFailureOperation = .decrementClamp
    stencilState.depthStencilPassOperation = .decrementClamp
    stencilState.readMask = 0xFF
    stencilState.writeMask = 0xFF
    desc.depthCompareFunction = .greaterEqual // .lessEqual
    desc.frontFaceStencil = stencilState
    desc.backFaceStencil = stencilState
    let lightColorStencilState = device.makeDepthStencilState(descriptor: desc)

    desc.depthCompareFunction = .always
    let lightColorStencilStateNoDepth = device.makeDepthStencilState(descriptor: desc)

    return (lightColorStencilState, lightColorStencilStateNoDepth)
}

class PointLightDrawer: Drawer {
    let pointLightCount: Int
    let lightMaskRenderPipelineState: MTLRenderPipelineState
    let lightColorRenderPipelineState: MTLRenderPipelineState
    let lightMaskStencilState: MTLDepthStencilState
    let lightColorStencilState: MTLDepthStencilState
    let lightColorStencilStateNoDepth: MTLDepthStencilState
    let lightModelMatrixBufferProvider: BufferProvider
    let lightDataBufferProvider: BufferProvider
    let lightModelVertexBuffer: MTLBuffer
    let lightModelIndexBuffer: MTLBuffer

    var cntr = 0

    init(device: MTLDevice, pixelFormatSpec: PixelFormatSpec, lightCount: Int) {
        pointLightCount = lightCount

        (lightMaskRenderPipelineState, lightColorRenderPipelineState) = MakeRenderPipelineState(device, pixelFormatSpec)
        lightMaskStencilState = MakeLightMaskStencilState(device)
        (lightColorStencilState, lightColorStencilStateNoDepth) = MakeLightColorStencilState(device)

        lightModelMatrixBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<LightModelMatrices>.stride * lightCount)
        lightDataBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<LightFragmentInputs>.stride * lightCount)

        (lightModelVertexBuffer, lightModelIndexBuffer) = MakeIcosahedron(device)
    }

    func draw(_ renderer: Renderer) {
        guard let renderEncoder = renderer.renderCommandEncoder else {
            return
        }

        renderEncoder.pushDebugGroup("light accumulation")

        let near = Float(0.1)

        let lightModelMatrixBuffer = lightModelMatrixBufferProvider.nextBuffer()
        let lightDataBuffer = lightDataBufferProvider.nextBuffer()

        let gpuLights = lightDataBuffer.contents().bindMemory(
            to: LightFragmentInputs.self,
            capacity: lightDataBuffer.length / MemoryLayout<LightFragmentInputs>.stride)
        let matrixData = lightModelMatrixBuffer.contents().bindMemory(
            to: LightModelMatrices.self,
            capacity: lightModelMatrixBuffer.length / MemoryLayout<LightModelMatrices>.stride)

        var pointLightMatrices = [LightModelMatrices](
            repeating: LightModelMatrices(mvpMatrix: GLKMatrix4Identity, mvMatrix: GLKMatrix4Identity),
            count: pointLightCount)
        let structureCameraMatrix = renderer.viewMatrix


        let speed: Float = 2.0
        let t = Float(cntr) / 60.0 * speed
        let size = Float(10)
        let r = Float(6)
        let lx = cos(t * 3.14) * r
        let ly = Float(10)
        let lz = sin(t * 3.14) * r
        let lw = Float(1)
        var lightData = LightFragmentInputs(
            lightPosition: GLKVector4Make(lx, ly, lz, lw),
            viewLightPosition: GLKVector4(),
            lightColorRadius: GLKVector4Make(1, 0.2, 0.2, size)
        )

        for i in 0..<self.pointLightCount {
            pointLightMatrices[i].mvMatrix = structureCameraMatrix.multiply(
                GLKMatrix4MakeTranslation(
                    lightData.lightPosition[0],
                    lightData.lightPosition[1],
                    lightData.lightPosition[2]))

            pointLightMatrices[i].mvMatrix = pointLightMatrices[i].mvMatrix.multiply(GLKMatrix4MakeScale(lightData.lightColorRadius[3], lightData.lightColorRadius[3], lightData.lightColorRadius[3]))
            pointLightMatrices[i].mvpMatrix = renderer.projectionMatrix.multiply(pointLightMatrices[i].mvMatrix)

            memcpy(matrixData.advanced(by: i), &pointLightMatrices[i], MemoryLayout<LightModelMatrices>.size)

            lightData.viewLightPosition = structureCameraMatrix.multiplyVector4(lightData.lightPosition)
            memcpy(gpuLights.advanced(by: i), &lightData, MemoryLayout<LightFragmentInputs>.size)

            renderEncoder.pushDebugGroup("stencil")
            renderEncoder.setRenderPipelineState(lightMaskRenderPipelineState)

            renderEncoder.setDepthStencilState(lightMaskStencilState)
            renderEncoder.setStencilReferenceValue(128)
            renderEncoder.setCullMode(.front)

            renderEncoder.setVertexBuffer(lightModelVertexBuffer, offset: 0, at: 0)
            renderEncoder.setVertexBuffer(lightModelMatrixBuffer, offset: i * MemoryLayout<LightModelMatrices>.stride, at: 1)
            renderEncoder.drawIndexedPrimitives(
                type: .triangle, indexCount: 60, indexType: .uint16, indexBuffer: lightModelIndexBuffer, indexBufferOffset: 0)

            renderEncoder.popDebugGroup()

            renderEncoder.pushDebugGroup("volume")

            // shade the front face if it won't clip through the front plane, otherwise use the back plane
            renderEncoder.setRenderPipelineState(lightColorRenderPipelineState)

            //let clip = lightData.lightPosition[2] + lightData.lightColorRadius[3] * circumscribe / inscribe < near
            let clip = fabs(lightData.viewLightPosition[2] + lightData.lightColorRadius[3] * circumscribe / inscribe) < near

            if clip {
                renderEncoder.setDepthStencilState(lightColorStencilStateNoDepth)
                renderEncoder.setCullMode(.front)
            } else {
                renderEncoder.setDepthStencilState(lightColorStencilState)
                renderEncoder.setCullMode(.back)
            }

            renderEncoder.setStencilReferenceValue(128)

            renderEncoder.setVertexBuffer(lightModelVertexBuffer, offset: 0, at: 0)
            renderEncoder.setVertexBuffer(lightModelMatrixBuffer, offset: i * MemoryLayout<LightModelMatrices>.stride, at: 1)
            renderEncoder.setFragmentBuffer(lightDataBuffer, offset: i * MemoryLayout<LightFragmentInputs>.stride, at: 0)
            renderEncoder.drawIndexedPrimitives(
                type: .triangle, indexCount: 60, indexType: .uint16, indexBuffer: lightModelIndexBuffer, indexBufferOffset: 0)

            renderEncoder.popDebugGroup()
        }

        renderEncoder.popDebugGroup()

        self.cntr += 1
    }
}
