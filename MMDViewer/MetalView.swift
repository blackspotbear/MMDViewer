import Foundation
import UIKit
import Metal

private let depthTextureSampleCount = 1

struct PixelFormatSpec {
    var colorAttachmentFormats = [MTLPixelFormat](repeating: .invalid, count: 4)
    var clearColors = [MTLClearColor](repeating: MTLClearColorMake(0, 0, 0, 0), count: 4)
    var depthPixelFormat = MTLPixelFormat.invalid
    var stencilPixelFormat = MTLPixelFormat.invalid
}

class MetalView: UIView {
    var device: MTLDevice?
    var pixelFormatSpec = PixelFormatSpec()

    var renderPassDescriptor: MTLRenderPassDescriptor? {
        if let drawable = currentDrawable {
            setupRenderPassDescriptorForTexture(drawable.texture)
        } else {
            _renderPassDescriptor = nil
        }
        return _renderPassDescriptor
    }

    var currentDrawable: CAMetalDrawable? {
        if _currentDrawable == nil {
            if let metalLayer = metalLayer {
                _currentDrawable = metalLayer.nextDrawable()
            } else {
                fatalError("failed to get a drawable")
            }
        }
        return _currentDrawable
    }

    var drawableSize: CGSize {
        set (v) {
            if let metalLayer = metalLayer {
                metalLayer.drawableSize = v
            }
        }
        get {
            if let metalLayer = metalLayer {
                return metalLayer.drawableSize
            } else {
                return CGSize.zero
            }
        }
    }

    private var _currentDrawable: CAMetalDrawable?
    private var _renderPassDescriptor: MTLRenderPassDescriptor?
    weak var metalLayer: CAMetalLayer?

    private var depthTex: MTLTexture?
    private var stencilTex: MTLTexture?
    private var colorTextures = [MTLTexture?](repeating:nil, count: 3)

    override init(frame: CGRect) {
        super.init(frame: frame)
        initMetalLayer()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initMetalLayer()
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

    func releaseCurrentDrawable() {
        _currentDrawable = nil
    }

    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    private final func initMetalLayer() {
        if let metalLayer = self.layer as? CAMetalLayer {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("can't create system default device")
            }
            metalLayer.device = device

            self.device = device
            self.metalLayer = metalLayer
        }
    }

    private func setupRenderPassDescriptorForTexture(_ texture: MTLTexture) {
        if _renderPassDescriptor == nil {
            _renderPassDescriptor = MTLRenderPassDescriptor()
        }

        guard let renderPassDescriptor = _renderPassDescriptor else {
            return
        }

        // color attachment #0
        if let colorAttachment = renderPassDescriptor.colorAttachments[0] {
            colorAttachment.texture = texture
            colorAttachment.loadAction = .clear
            colorAttachment.clearColor = self.pixelFormatSpec.clearColors[0]
            colorAttachment.storeAction = .store
        }

        // update color attachment #1 ~ 3
        for i in 1...3 {
            let format = self.pixelFormatSpec.colorAttachmentFormats[i]
            if format == .invalid {
                continue
            }

            var doUpdate = false
            if let colorTexture = colorTextures[i - 1] {
                doUpdate = colorTexture.width != texture.width || colorTexture.height != texture.height
            } else {
                doUpdate = true
            }

            if doUpdate {
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormatSpec.colorAttachmentFormats[i],
                    width: texture.width, height: texture.height,
                    mipmapped: false)
                colorTextures[i - 1] = device!.makeTexture(descriptor: desc)

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
                    (tex.width       != texture.width)  ||
                    (tex.height      != texture.height) ||
                    (tex.sampleCount != depthTextureSampleCount)
            } else {
                doUpdate = true
            }

            if doUpdate {
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormatSpec.depthPixelFormat,
                    width: texture.width,
                    height: texture.height,
                    mipmapped: false)
                desc.textureType = (depthTextureSampleCount > 1) ? .type2DMultisample : .type2D
                desc.sampleCount = depthTextureSampleCount
                depthTex = device!.makeTexture(descriptor: desc)

                if let depthTex = depthTex {
                    print(String(format:"update depth texture (%d, %d)", depthTex.width, depthTex.height))

                    if let attachment = renderPassDescriptor.depthAttachment {
                        attachment.texture = depthTex
                        attachment.loadAction = .clear
                        attachment.storeAction = .dontCare
                        attachment.clearDepth = 1.0
                    }
                }
            }
        }

        // update stencil texture
        if pixelFormatSpec.stencilPixelFormat != .invalid {
            var doUpdate = false
            if let tex = stencilTex {
                doUpdate = tex.width != texture.width || tex.height != texture.height
            } else {
                doUpdate = true
            }

            if doUpdate {
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: pixelFormatSpec.stencilPixelFormat,
                    width: texture.width,
                    height: texture.height,
                    mipmapped: false)
                desc.textureType = .type2D
                stencilTex = device!.makeTexture(descriptor: desc)

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
    }
}
