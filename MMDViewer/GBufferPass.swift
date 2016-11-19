import Foundation
import Metal
import simd

private let depthTextureSampleCount = 1

private class PassResource {
    var pixelFormatSpec = PixelFormatSpec()
    let device: MTLDevice
    var colorTextures = [MTLTexture?](repeating:nil, count: 3)
    var depthTex: MTLTexture?
    var stencilTex: MTLTexture?

    private var renderPassDescriptor = MTLRenderPassDescriptor()

    init(device: MTLDevice) {
        self.device = device
    }

    func releaseTextures() {
        print("releasing textures...")

        depthTex = nil
        stencilTex = nil
        for i in 0..<colorTextures.count {
            colorTextures[i] = nil
        }

        print("done")
    }

    func renderPassDescriptorForDrawable(_ drawable: MTLTexture) -> MTLRenderPassDescriptor {

        // color attachment #0
        if let colorAttachment = renderPassDescriptor.colorAttachments[0] {
            colorAttachment.texture = drawable
            colorAttachment.loadAction = .clear
            colorAttachment.clearColor = pixelFormatSpec.clearColors[0]
            colorAttachment.storeAction = .store
        }

        // update color attachment #1 ~ 3
        for i in 1...3 {
            let format = pixelFormatSpec.colorAttachmentFormats[i]
            if format == .invalid {
                continue
            }

            var doUpdate = false
            if let colorTexture = colorTextures[i - 1] {
                doUpdate = colorTexture.width != drawable.width || colorTexture.height != drawable.height
            } else {
                doUpdate = true
            }

            if doUpdate {
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormatSpec.colorAttachmentFormats[i],
                    width: drawable.width, height: drawable.height,
                    mipmapped: false)
                colorTextures[i - 1] = device.makeTexture(descriptor: desc)

                if let colorTexture = colorTextures[i - 1] {
                    print(String(format:"update color texture [%d] (%d, %d)", i, colorTexture.width, colorTexture.height))

                    if let attachment = renderPassDescriptor.colorAttachments[i] {
                        attachment.texture = colorTexture
                        attachment.loadAction = .clear
                        attachment.storeAction = .dontCare
                        attachment.clearColor = pixelFormatSpec.clearColors[i]
                    }
                }
            }
        }

        // update depth texture
        if pixelFormatSpec.depthPixelFormat != .invalid {
            var doUpdate = false
            if let tex = depthTex {
                doUpdate =
                    (tex.width       != drawable.width)  ||
                    (tex.height      != drawable.height) ||
                    (tex.sampleCount != depthTextureSampleCount)
            } else {
                doUpdate = true
            }

            if doUpdate {
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormatSpec.depthPixelFormat,
                    width: drawable.width,
                    height: drawable.height,
                    mipmapped: false)
                desc.textureType = (depthTextureSampleCount > 1) ? .type2DMultisample : .type2D
                desc.sampleCount = depthTextureSampleCount
                depthTex = device.makeTexture(descriptor: desc)

                if let depthTex = depthTex {
                    print(String(format:"update depth texture (%d, %d)", depthTex.width, depthTex.height))

                    if let attachment = renderPassDescriptor.depthAttachment {
                        attachment.texture = depthTex
                        attachment.loadAction = .clear
                        attachment.storeAction = .store
                        attachment.clearDepth = 1.0
                    }
                }
            }
        }

        // update stencil texture
        if pixelFormatSpec.stencilPixelFormat != .invalid {
            var doUpdate = false
            if let tex = stencilTex {
                doUpdate = tex.width != drawable.width || tex.height != drawable.height
            } else {
                doUpdate = true
            }

            if doUpdate {
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormatSpec.stencilPixelFormat,
                    width: drawable.width,
                    height: drawable.height,
                    mipmapped: false)
                desc.textureType = .type2D
                stencilTex = device.makeTexture(descriptor: desc)

                if let stencilTex = stencilTex {
                    print(String(format:"update stencil texture (%d, %d)", stencilTex.width, stencilTex.height))

                    if let attachment = renderPassDescriptor.stencilAttachment {
                        attachment.texture = stencilTex
                        attachment.loadAction = .clear
                        attachment.storeAction = .dontCare
                        attachment.clearStencil = 0
                    }
                }
            }
        }

        return renderPassDescriptor
    }
}

struct MaterialSunData {
    var sunDirection: float4
    var sunColor: float4
}

private func newFunctionFromLibrary(_ library: MTLLibrary, name: String) -> MTLFunction {
    guard let fn = library.makeFunction(name: name) else {
        fatalError(String(format: "faled to load function %s", name))
    }
    return fn
}

private func MakeDepthStencilState(_ device: MTLDevice) -> MTLDepthStencilState {
    let desc = MTLDepthStencilDescriptor()
    desc.isDepthWriteEnabled = true
    desc.depthCompareFunction = .lessEqual
    return device.makeDepthStencilState(descriptor: desc)
}

class GBufferPass: RenderPass {
    private let passRes: PassResource

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

    class private func createGBufferRenderPipelineState(_ device: MTLDevice, library: MTLLibrary, passRes: PassResource) -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "GBuffer Render"

        // pixel format
        for i in 0...3 {
            desc.colorAttachments[i].pixelFormat = passRes.pixelFormatSpec.colorAttachmentFormats[i]
        }
        desc.depthAttachmentPixelFormat = passRes.pixelFormatSpec.depthPixelFormat
        desc.stencilAttachmentPixelFormat = passRes.pixelFormatSpec.stencilPixelFormat

        // shader function
        desc.vertexFunction = newFunctionFromLibrary(library, name: "gBufferVert")
        desc.fragmentFunction = newFunctionFromLibrary(library, name: "gBufferFrag")

        return try! device.makeRenderPipelineState(descriptor: desc)
    }

    class private func createCompositionRenderPipelineState(_ device: MTLDevice, library: MTLLibrary, passRes: PassResource) -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()

        desc.label = "Composition Render"

        for i in 0...3 {
            desc.colorAttachments[i].pixelFormat = passRes.pixelFormatSpec.colorAttachmentFormats[i]
        }
        desc.depthAttachmentPixelFormat = passRes.pixelFormatSpec.depthPixelFormat
        desc.stencilAttachmentPixelFormat = passRes.pixelFormatSpec.stencilPixelFormat
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

        passRes = PassResource(device: device)

        passRes.pixelFormatSpec.colorAttachmentFormats[0] = .bgra8Unorm
        passRes.pixelFormatSpec.colorAttachmentFormats[1] = .bgra8Unorm
        passRes.pixelFormatSpec.colorAttachmentFormats[2] = .r32Float
        passRes.pixelFormatSpec.colorAttachmentFormats[3] = .bgra8Unorm
        passRes.pixelFormatSpec.depthPixelFormat = .depth32Float
        passRes.pixelFormatSpec.stencilPixelFormat = .stencil8
        passRes.pixelFormatSpec.clearColors[0] = MTLClearColorMake(
            1.0   * 0.75 + 0.075,
            0.875 * 0.75 + 0.075,
            0.75  * 0.75 + 0.075,
            1.0)
        passRes.pixelFormatSpec.clearColors[1] = MTLClearColorMake(0, 0, 0, 1)
        passRes.pixelFormatSpec.clearColors[2] = MTLClearColorMake(25, 25, 25, 25)
        passRes.pixelFormatSpec.clearColors[3] = MTLClearColorMake(0.1, 0.1, 0.125, 0.0)

        self.view = view

        for _ in 0..<numFrames {
            sunDataBuffers.append(device.makeBuffer(length: MemoryLayout<MaterialSunData>.size, options: MTLResourceOptions()))
        }

        compositionDepthState = GBufferPass.createCompositionDepthState(device)
        compositionPipeline = GBufferPass.createCompositionRenderPipelineState(device, library: defaultLibrary, passRes: passRes)
        shadowDepthStencilState = MakeDepthStencilState(device)
        gbufferRenderRipeline = GBufferPass.createGBufferRenderPipelineState(device, library: defaultLibrary, passRes: passRes)

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
        guard let currentDrawable = view.currentDrawable else {
            return
        }

        var renderer = renderer
        let renderPassDescriptor = passRes.renderPassDescriptorForDrawable(currentDrawable.texture)
        renderer.textureResources["ColorBuffer"] = currentDrawable.texture
        renderer.textureResources["NormalBuffer"] = passRes.colorTextures[0]
        renderer.textureResources["LinearDBuffer"] = passRes.colorTextures[1]
        renderer.textureResources["LightBuffer"] = passRes.colorTextures[2]
        renderer.textureResources["DepthBuffer"] = passRes.depthTex
        renderer.textureResources["StencilBuffer"] = passRes.stencilTex

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
        }
    }

    private func drawQuad(_ encoder: MTLRenderCommandEncoder) {
        encoder.setVertexBuffer(quadPositionBuffer, offset: 0, at: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
