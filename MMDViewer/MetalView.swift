import Foundation
import UIKit
import Metal

class MetalView: UIView {
    var device: MTLDevice?
    var depthPixelFormat = MTLPixelFormat.Invalid
    var sampleCount = 0
    
    var renderPassDescriptor: MTLRenderPassDescriptor? {
        if let drawable = currentDrawable {
            setupRenderPassDescriptorForTexture(drawable.texture)
        } else {
            _renderPassDescriptor = nil;
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
        return _currentDrawable;
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
                return CGSizeZero
            }
        }
    }
    
    private var _currentDrawable: CAMetalDrawable?
    private var _renderPassDescriptor: MTLRenderPassDescriptor?
    private weak var metalLayer: CAMetalLayer?
    private var depthTex: MTLTexture?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initMetalLayer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initMetalLayer()
    }
    
    func releaseTextures() {
        depthTex   = nil
    }
    
    func releaseCurrentDrawable() {
        _currentDrawable = nil
    }
    
    override class func layerClass() -> AnyClass {
        return CAMetalLayer.self
    }
    
    private final func initMetalLayer() {
        if let metalLayer = self.layer as? CAMetalLayer {
            device = MTLCreateSystemDefaultDevice()!
            
            metalLayer.device = device
            metalLayer.pixelFormat = MTLPixelFormat.BGRA8Unorm
            metalLayer.framebufferOnly = true
            
            self.metalLayer = metalLayer
        }
    }
    
    private func setupRenderPassDescriptorForTexture(texture: MTLTexture) {
        if _renderPassDescriptor == nil {
            _renderPassDescriptor = MTLRenderPassDescriptor()
        }
        
        if let renderPassDescriptor = _renderPassDescriptor {
            let colorAttachment = renderPassDescriptor.colorAttachments[0]
            colorAttachment.texture = texture
            colorAttachment.loadAction = MTLLoadAction.Clear
            colorAttachment.clearColor = MTLClearColorMake(0.0, 0.35, 0.65, 1.0)
            colorAttachment.storeAction = MTLStoreAction.Store;
            
            if depthPixelFormat != MTLPixelFormat.Invalid {
                var doUpdate = false
                if let depthTex = depthTex {
                    doUpdate =
                        (depthTex.width       != texture.width)  ||
                        (depthTex.height      != texture.height) ||
                        (depthTex.sampleCount != sampleCount)
                }
                
                if depthTex == nil || doUpdate {
                    
                    let desc = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        depthPixelFormat,
                        width: texture.width,
                        height: texture.height,
                        mipmapped: false
                    )
                    desc.textureType = (sampleCount > 1) ? MTLTextureType.Type2DMultisample : MTLTextureType.Type2D
                    desc.sampleCount = sampleCount
                    depthTex = device!.newTextureWithDescriptor(desc)
                    
                    let depthAttachment = renderPassDescriptor.depthAttachment
                    depthAttachment.texture = depthTex
                    depthAttachment.loadAction = MTLLoadAction.Clear
                    depthAttachment.storeAction = MTLStoreAction.DontCare
                    depthAttachment.clearDepth = 1.0
                }
            }
        }
    }
}
