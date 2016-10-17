import Foundation
import UIKit
import Metal

class MMDView: MetalView {
    var pmxUpdater: PMXUpdater?

    private var renderer = BasicRenderer()
    private var traverser: Traverser
    private var root = Node()

    private var timer: CADisplayLink!
    private var lastFrameTimestamp: CFTimeInterval = 0.0

    private var pmx: PMX!
    private var vmd: VMD!
    private var miku: PMXObject!

    private var panGestureRecognizer: UIGestureRecognizer!
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var layerSizeDidUpdate = false

    override init(frame: CGRect) {
        traverser = Traverser(renderer: renderer)
        super.init(frame: frame)
        renderer.configure(device!)
        initCommon()
    }

    required init?(coder aDecoder: NSCoder) {
        traverser = Traverser(renderer: renderer)
        super.init(coder: aDecoder)
        renderer.configure(device!)
        initCommon()
    }

    private func initCommon() {
        isOpaque = true
        backgroundColor = nil

        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MMDView.gestureRecognizerDidRecognize(_:)))
        addGestureRecognizer(panGestureRecognizer)
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MMDView.handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
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
        layerSizeDidUpdate = true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        contentScaleFactor = self.window!.screen.nativeScale

        // Load resource
        pmx = LoadPMD("data/mmd/Alicia_solid")
        vmd = LoadVMD("data/vmd/2分ループステップ17")
        miku = PMXObject(device: device!, pmx: pmx!, vmd: vmd)

        setupSceneGraph()

        if let metalLayer = self.metalLayer {
            metalLayer.pixelFormat = self.pixelFormatSpec.colorAttachmentFormats[0]
            metalLayer.framebufferOnly = true
        }

        // Set up animation loop
        timer = CADisplayLink(target: self, selector: #selector(MMDView.mainLoop(_:)))
        if #available(iOS 10.0, *) {
            timer.preferredFramesPerSecond = 30
        } else {
            timer.frameInterval = 2
        }
        timer.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
    }

    #if false

    private func setupSceneGraph() {
        pmxUpdater = PMXUpdater(pmxObj: miku)
        root.updater = pmxUpdater
        root.drawer = PMXDrawer(pmxObj: miku, device: device!)
        root.pass = PresentViewRenderPass(view: self)
    }

    #else

    private func setupSceneGraph() {
        let shadowNode = Node()
        let shadowPass = ShadowPass(device: device!)
        shadowNode.pass = shadowPass
        shadowNode.drawer = PMXShadowDrawer(pmxObj: miku)

        let gbufferNode = Node()
        gbufferNode.pass = GBufferPass(view: self)

        let pmxDrawNode = Node()
        pmxDrawNode.drawer = PMXGBufferDrawer(
            device: device!,
            pmxObj: miku,
            pixelFormatSpec: pixelFormatSpec,
            shadowTexture: shadowPass.shadowTexture)

        let pointLightNode = Node()
        pointLightNode.drawer = PointLightDrawer(device: device!, pixelFormatSpec: pixelFormatSpec, lightCount: 1)

        gbufferNode.children.append(pmxDrawNode)
        gbufferNode.children.append(pointLightNode)

        pmxUpdater = PMXUpdater(pmxObj: miku)
        root.updater = pmxUpdater
        root.children.append(shadowNode)
        root.children.append(gbufferNode)
    }

    #endif

    // MARK: UI Event Handlers

    func gestureRecognizerDidRecognize(_ recognize: UIPanGestureRecognizer) {
        let v = recognize.velocity(in: self)
        if let pmxUpdater = pmxUpdater {
            pmxUpdater.angularVelocity = CGPoint(x: v.x * 0.01, y: v.y * 0.01)
        }
    }

    func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            // nothing to do
        }
    }

    // MARK: Loop

    func mainLoop(_ displayLink: CADisplayLink) {
        if lastFrameTimestamp == 0.0 {
            lastFrameTimestamp = displayLink.timestamp
        }

        let elapsed = displayLink.timestamp - lastFrameTimestamp
        lastFrameTimestamp = displayLink.timestamp

        if layerSizeDidUpdate {
            var drawableSize = self.bounds.size
            drawableSize.width  *= contentScaleFactor
            drawableSize.height *= contentScaleFactor

            self.drawableSize = drawableSize
            renderer.reshape(self.bounds)

            layerSizeDidUpdate = false
        }

        traverser.update(elapsed, node: root)
        traverser.draw(root)
    }
}
