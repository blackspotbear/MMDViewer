import Foundation
import Metal
import simd

struct MaterialSunData {
    var sunDirection: float4
    var sunColor: float4
}

private func newFunctionFromLibrary(_ library: MTLLibrary, name: String) -> MTLFunction {
    let fn = library.makeFunction(name: name)
    if fn == nil {
        fatalError(String(format: "faled to load function %s", name))
    }
    return fn!
}

class GBufferPass: RenderPass {
    private var view: MetalView
    private var compositionPipeline: MTLRenderPipelineState
    private var sunDataBuffers: [MTLBuffer] = []
    private var compositionDepthState: MTLDepthStencilState
    private var currentFrame = 0
    private let numFrames = 3
    private var quadPositionBuffer: MTLBuffer
    private var shadowDepthStencilState: MTLDepthStencilState
    private var gbufferRenderRipeline: MTLRenderPipelineState
    private var gBufferDepthStencilState: MTLDepthStencilState

    class private func createGBufferRenderPipelineState(_ device: MTLDevice, library: MTLLibrary, view: MetalView) -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "GBuffer Render"

        // pixel format
        for i in 0...3 {
            desc.colorAttachments[i].pixelFormat = view.pixelFormatSpec.colorAttachmentFormats[i]
        }
        desc.depthAttachmentPixelFormat = view.pixelFormatSpec.depthPixelFormat
        desc.stencilAttachmentPixelFormat = view.pixelFormatSpec.stencilPixelFormat

        // shader function
        desc.vertexFunction = newFunctionFromLibrary(library, name: "gBufferVert")
        desc.fragmentFunction = newFunctionFromLibrary(library, name: "gBufferFrag")

        return try! device.makeRenderPipelineState(descriptor: desc)
    }

    class private func createCompositionRenderPipelineState(_ device: MTLDevice, library: MTLLibrary, view: MetalView) -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()

        desc.label = "Composition Render"

        for i in 0...3 {
            desc.colorAttachments[i].pixelFormat = view.pixelFormatSpec.colorAttachmentFormats[i]
        }
        desc.depthAttachmentPixelFormat = view.pixelFormatSpec.depthPixelFormat
        desc.stencilAttachmentPixelFormat = view.pixelFormatSpec.stencilPixelFormat
        desc.vertexFunction = newFunctionFromLibrary(library, name: "compositionVertex")
        desc.fragmentFunction = newFunctionFromLibrary(library, name: "compositionFrag")

        return try! device.makeRenderPipelineState(descriptor: desc)
    }

    class private func createCompositionDepthState(_ device: MTLDevice) -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        let stencilState = MTLStencilDescriptor()

        desc.isDepthWriteEnabled = false
        stencilState.stencilCompareFunction = .equal
        stencilState.stencilFailureOperation = .keep
        stencilState.depthFailureOperation = .keep
        stencilState.depthStencilPassOperation = .keep
        stencilState.readMask = 0xFF
        stencilState.writeMask = 0
        desc.depthCompareFunction = .always
        desc.frontFaceStencil = stencilState
        desc.backFaceStencil = stencilState

        return device.makeDepthStencilState(descriptor: desc)
    }

    init(view: MetalView) {
        guard let device = view.device else {
            fatalError("failed to get a device object")
        }
        guard let defaultLibrary = device.newDefaultLibrary() else {
            fatalError("failed to create a default library")
        }

        view.pixelFormatSpec.colorAttachmentFormats[0] = .bgra8Unorm
        view.pixelFormatSpec.colorAttachmentFormats[1] = .bgra8Unorm
        view.pixelFormatSpec.colorAttachmentFormats[2] = .r32Float
        view.pixelFormatSpec.colorAttachmentFormats[3] = .bgra8Unorm
        view.pixelFormatSpec.depthPixelFormat = .depth32Float
        view.pixelFormatSpec.stencilPixelFormat = .stencil8
        view.pixelFormatSpec.clearColors[0] = MTLClearColorMake(
            1.0   * 0.75 + 0.075,
            0.875 * 0.75 + 0.075,
            0.75  * 0.75 + 0.075,
            1.0)
        view.pixelFormatSpec.clearColors[1] = MTLClearColorMake(0, 0, 0, 1)
        view.pixelFormatSpec.clearColors[2] = MTLClearColorMake(25, 25, 25, 25)
        view.pixelFormatSpec.clearColors[3] = MTLClearColorMake(0.1, 0.1, 0.125, 0.0)

        self.view = view

        for _ in 0..<numFrames {
            sunDataBuffers.append(device.makeBuffer(length: MemoryLayout<MaterialSunData>.size, options: MTLResourceOptions()))
        }

        compositionDepthState = GBufferPass.createCompositionDepthState(device)
        compositionPipeline = GBufferPass.createCompositionRenderPipelineState(device, library: defaultLibrary, view: view)
        shadowDepthStencilState = ShadowPass.createDepthStencilState(device)
        gbufferRenderRipeline = GBufferPass.createGBufferRenderPipelineState(device, library: defaultLibrary, view: view)

        let quadVerts: [Float] = [
            -1.0, 1.0,
            1.0, -1.0,
            -1.0, -1.0,
            -1.0, 1.0,
            1.0, 1.0,
            1.0, -1.0
        ]

        quadPositionBuffer = device.makeBuffer(
            bytes: quadVerts,
            length: quadVerts.count * MemoryLayout<Float>.size,
            options: MTLResourceOptions()
        )

        let desc = MTLDepthStencilDescriptor()
        let stencilState = MTLStencilDescriptor()
        desc.isDepthWriteEnabled = true
        stencilState.stencilCompareFunction = .always
        stencilState.stencilFailureOperation = .keep
        stencilState.depthFailureOperation = .keep
        stencilState.depthStencilPassOperation = .replace
        stencilState.readMask = 0xFF
        stencilState.writeMask = 0xFF
        desc.depthCompareFunction = .lessEqual
        desc.frontFaceStencil = stencilState
        desc.backFaceStencil = stencilState
        gBufferDepthStencilState = device.makeDepthStencilState(descriptor: desc)
    }

    func begin(_ renderer: Renderer) {
        var renderer = renderer
        guard let renderPassDescriptor = view.renderPassDescriptor else {
            return
        }
        let encoder = renderer.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        encoder.pushDebugGroup("g-buffer pass")
        encoder.label = "g-buffer"
        encoder.setDepthStencilState(shadowDepthStencilState)

        encoder.setRenderPipelineState(gbufferRenderRipeline)
        encoder.setCullMode(.back)

        encoder.setDepthStencilState(gBufferDepthStencilState)
        encoder.setStencilReferenceValue(128)

        renderer.renderCommandEncoderStack.append(encoder)
    }

    func end(_ renderer: Renderer) {
        var renderer = renderer
        if let encoder = renderer.renderCommandEncoderStack.popLast() {
            encoder.popDebugGroup()

            encoder.pushDebugGroup("sun")
            encoder.setRenderPipelineState(compositionPipeline)
            encoder.setCullMode(.none)
            encoder.setDepthStencilState(compositionDepthState)
            encoder.setStencilReferenceValue(128)
            drawQuad(encoder)
            encoder.popDebugGroup()

            encoder.endEncoding()

            currentFrame = currentFrame + 1
            if currentFrame >= numFrames {
                currentFrame = 0
            }

            if let drawable = view.currentDrawable {
                if let commandBuffer = renderer.commandBuffer {
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
                view.releaseCurrentDrawable()
            }
        }
    }

    private func drawQuad(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(quadPositionBuffer, offset: 0, at: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
