import Foundation
import UIKit
import GLKit
import Metal

let InitialCameraPosition = GLKVector3Make(0, 10, 20)

class MMDView: MetalView {
    var pmxUpdater: PMXUpdater?
    private var cameraUpdater = CameraUpdater(rot: GLKVector3Make(0, 0, 0), pos: InitialCameraPosition)

    private var renderer = BasicRenderer()
    private var traverser: Traverser
    private var root = Node()

    private var timer: CADisplayLink!
    private var lastFrameTimestamp: CFTimeInterval = 0.0

    private var pmx: PMX!
    private var vmd: VMD!
    private var miku: PMXObject!

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

//    private panRecognizer: UIPanGestureRecognizer

    private func initCommon() {
        isOpaque = true
        backgroundColor = nil

        let tapg = UITapGestureRecognizer(target: self, action: #selector(MMDView.handleTap(_:)))
        tapg.numberOfTapsRequired = 2
        addGestureRecognizer(tapg)
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(MMDView.handlePan(_:))))
        addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(MMDView.handlePinch(_:))))
        addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(MMDView.handleRotate(_:))))
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

        renderer.setEndHandler({ [weak self] (_ renderer: Renderer) in
            if let drawable = self?.currentDrawable {
                if let commandBuffer = renderer.commandBuffer {
                    commandBuffer.present(drawable)
                    commandBuffer.commit()
                }
                self?.releaseCurrentDrawable()
            }
        })

        let colorFormat = setupSceneGraph()

        if let metalLayer = self.metalLayer {
            metalLayer.pixelFormat = colorFormat
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

    private func setupSceneGraph() -> MTLPixelFormat {
        let node = Node()
        pmxUpdater = PMXUpdater(pmxObj: miku)
        node.updater = pmxUpdater
        node.drawer = PMXDrawer(pmxObj: miku, device: device!)
        node.pass = ForwardRenderPass(view: self)

        root.updater = cameraUpdater
        root.children.append(node)

        return .bgra8Unorm
    }

    #else

    private func setupSceneGraph() -> MTLPixelFormat {
        let shadowNode = Node()
        let shadowPass = ShadowPass(device: device!)
        shadowNode.pass = shadowPass
        shadowNode.drawer = PMXShadowDrawer(pmxObj: miku)

        let gbufferNode = Node()
        let gbufferPass = GBufferPass(view: self)
        gbufferNode.pass = gbufferPass

        let pmxDrawNode = Node()
        pmxDrawNode.drawer = PMXGBufferDrawer(
            device: device!,
            pmxObj: miku,
            shadowTexture: shadowPass.shadowTexture)

        let pointLightNode = Node()
        pointLightNode.drawer = PointLightDrawer(
            device: device!,
            lightCount: 1)

        gbufferNode.children.append(pmxDrawNode)
        gbufferNode.children.append(pointLightNode)

        let wireframeNode = Node()
        let wireframePass = WireframePass(device: device!)
        wireframeNode.pass = wireframePass
        wireframeNode.drawer = WireFrameDrawer(device: device!)


        let node = Node()
        pmxUpdater = PMXUpdater(pmxObj: miku)
        node.updater = pmxUpdater
        node.children.append(shadowNode)
        node.children.append(gbufferNode)
        node.children.append(wireframeNode)

        root.updater = cameraUpdater
        root.children.append(node)

        return .bgra8Unorm
    }

    #endif

    // MARK: UI Event Handlers

    func handlePan(_ recognize: UIPanGestureRecognizer) {
        let t = recognize.translation(in: self)
        let dx = Float(t.x)
        let dy = Float(t.y)
        if recognize.numberOfTouches == 1 {
            cameraUpdater.r = GLKVector3Add(cameraUpdater.r, GLKVector3Make(dy / 100, dx / 100, 0))
        } else if recognize.numberOfTouches == 2 {
            let dX = GLKVector3MultiplyScalar(cameraUpdater.viewMatrix.ixAxis(), -dx / 10)
            let dY = GLKVector3MultiplyScalar(cameraUpdater.viewMatrix.iyAxis(), dy / 10)
            cameraUpdater.x = GLKVector3Add(GLKVector3Add(cameraUpdater.x, dX), dY)
        }

        recognize.setTranslation(CGPoint(x: 0, y: 0), in: self)
    }

    func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            cameraUpdater.x = InitialCameraPosition
            cameraUpdater.r = GLKVector3Make(0, 0, 0)
        }
    }

    func handlePinch(_ recognize: UIPinchGestureRecognizer) {
        let v = Float(recognize.velocity)
        let dZ = GLKVector3MultiplyScalar(cameraUpdater.viewMatrix.izAxis(), -v)
        cameraUpdater.x = GLKVector3Add(cameraUpdater.x, dZ)
        recognize.scale = 1
    }

    func handleRotate(_ recognize: UIRotationGestureRecognizer) {
        let v = Float(recognize.velocity) * 0.05
        cameraUpdater.r = GLKVector3Add(cameraUpdater.r, GLKVector3Make(0, 0, v))
        recognize.rotation = 0
    }

    // MARK: Loop

    func mainLoop(_ displayLink: CADisplayLink) {
        if lastFrameTimestamp == 0.0 {
            lastFrameTimestamp = displayLink.timestamp
        }

        let elapsed = displayLink.timestamp - lastFrameTimestamp
        lastFrameTimestamp = displayLink.timestamp

        if layerSizeDidUpdate {
            self.drawableSize.width = self.bounds.size.width * contentScaleFactor
            self.drawableSize.height = self.bounds.size.height * contentScaleFactor

            renderer.reshape(self.bounds)

            layerSizeDidUpdate = false
        }

        traverser.update(elapsed, node: root)
        traverser.draw(root)
    }
}
