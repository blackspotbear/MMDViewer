import Foundation
import UIKit
import Metal

class MMDView: MetalView {
    var playing = true
    
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
        
        renderer = Renderer()
        renderer.configure(self)
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
        
        // Set up animation loop
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
                
                self.drawableSize = drawableSize;
                renderer.reshape(self)
                
                layerSizeDidUpdate = false;
            }
            
            renderer.begin(self)
            miku.render(renderer)
            renderer.end(self)
            
            releaseCurrentDrawable()
        }
    }
}
