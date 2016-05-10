import Foundation
import UIKit
import Metal

class MMDView: UIView {
    var device: MTLDevice?
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
    var depthPixelFormat = MTLPixelFormat.Invalid
    var stencilPixelFormat = MTLPixelFormat.Invalid
    var sampleCount = 0
    
    var playing = true
    
    private var depthTex: MTLTexture?
    private var stencilTex: MTLTexture?
    private var msaaTex: MTLTexture?
    private weak var metalLayer: CAMetalLayer?
    private var _currentDrawable: CAMetalDrawable?
    private var _renderPassDescriptor: MTLRenderPassDescriptor?
    private var renderer = Renderer()
    
    private var timer: CADisplayLink!
    private var lastFrameTimestamp: CFTimeInterval = 0.0
    
    private var pmx: PMX!
    private var vmd: VMD!
    private var miku: PMXModel!
    
    private var panGestureRecognizer: UIGestureRecognizer!
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var angularVelocity = CGPointMake(0, 0)
    private var layerSizeDidUpdate = false
    
    override class func layerClass() -> AnyClass {
        return CAMetalLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initCommon()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initCommon()
    }
    
    private func initCommon() {
        opaque          = true
        backgroundColor = nil
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MMDView.gestureRecognizerDidRecognize(_:)))
        addGestureRecognizer(panGestureRecognizer)
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MMDView.handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
        
        if let metalLayer = self.layer as? CAMetalLayer {
            device = MTLCreateSystemDefaultDevice()!
            
            metalLayer.device = device
            metalLayer.pixelFormat = MTLPixelFormat.BGRA8Unorm
            metalLayer.framebufferOnly = true
            
            self.metalLayer = metalLayer
        }
        
        renderer = Renderer()
        renderer.configure(self)
    }
    
    func releaseTextures() {
        depthTex   = nil;
        stencilTex = nil;
        msaaTex    = nil;
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
                        ( depthTex.width       != texture.width)  ||
                        ( depthTex.height      != texture.height) ||
                        ( depthTex.sampleCount != sampleCount)
                    
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
    
    // MARK: Override UIView
    
    override var contentScaleFactor: CGFloat {
        set(v) {
            super.contentScaleFactor = v
            layerSizeDidUpdate = true
        }
        get {
            return super.contentScaleFactor
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layerSizeDidUpdate = true;
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        contentScaleFactor = self.window!.screen.nativeScale
        
        // Load resource
        pmx = LoadPMD("data/mmd/Alicia_solid")
        vmd = LoadVMD("data/vmd/2分ループステップ17")
        miku = PMXModel(device: device!, pmx: pmx!, vmd: vmd)
        
        // Set up Game loop
        timer = CADisplayLink(target: self, selector: #selector(MMDView.mainLoop(_:)))
        timer.frameInterval = 2
        timer.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
    }
    
    // MARK: UI Event Handlers
    
    func gestureRecognizerDidRecognize(recognize: UIPanGestureRecognizer) {
        let v = recognize.velocityInView(self)
        angularVelocity = CGPointMake(v.x * 0.01, v.y * 0.01)
    }
    
    func handleTap(sender: UITapGestureRecognizer) {
        if sender.state == .Ended {
            // nothing to do
        }
    }
    
    // MARK: Loop
    
    func mainLoop(displayLink: CADisplayLink) {
        if lastFrameTimestamp == 0.0 {
            lastFrameTimestamp = displayLink.timestamp
        }
        
        let elapsed = displayLink.timestamp - lastFrameTimestamp
        lastFrameTimestamp = displayLink.timestamp
        
        update(timeSinceLastUpdate: elapsed)
        draw();
    }
    
    func update(timeSinceLastUpdate timeSinceLastUpdate: CFTimeInterval) {
        if timeSinceLastUpdate > 0 {
            miku.rotationX += Float(angularVelocity.y * CGFloat(timeSinceLastUpdate))
            miku.rotationY += Float(angularVelocity.x * CGFloat(timeSinceLastUpdate))
            angularVelocity.x *= 0.95
            angularVelocity.y *= 0.95
        }
        
        if playing {
            miku.updateCounter()
            miku.calc()
        }
    }
    
    func draw() {
        autoreleasepool {
            if layerSizeDidUpdate {
                var drawableSize = self.bounds.size;
                drawableSize.width  *= self.contentScaleFactor;
                drawableSize.height *= self.contentScaleFactor;
                
                metalLayer!.drawableSize = drawableSize;
                renderer.reshape(self)
                
                layerSizeDidUpdate = false;
            }
            
            renderer.begin(self)
            miku.render(renderer)
            renderer.end(self)
            
            _currentDrawable = nil;
        }
    }
}
