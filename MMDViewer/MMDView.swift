import Foundation
import UIKit
import GLKit
import Metal

let InitialCameraPosition = GLKVector3Make(0, 10, 20)

/// `melt` のアプリ固有 view。
/// Metal drawable の獲得は `MetalView` に任せ、この型は scene graph 構築と frame 駆動を束ねる。
class MMDView: MetalView {
    var pmxUpdater: PMXUpdater?
    private var cameraUpdater = CameraUpdater(rot: GLKQuaternionIdentity, pos: InitialCameraPosition)

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
        registerGestureRecognizers()
    }

    private func registerGestureRecognizers() {
        addGestureRecognizer(makeTapGestureRecognizer())
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(MMDView.handlePan(_:))))
        addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(MMDView.handlePinch(_:))))
        addGestureRecognizer(UIRotationGestureRecognizer(target: self, action: #selector(MMDView.handleRotate(_:))))
    }

    private func makeTapGestureRecognizer() -> UITapGestureRecognizer {
        let tapg = UITapGestureRecognizer(target: self, action: #selector(MMDView.handleTap(_:)))
        tapg.numberOfTapsRequired = 2
        return tapg
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
        metalLayer?.frame = bounds
        layerSizeDidUpdate = true
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        guard let window else {
            return
        }

        configureForWindow(window)
    }

    #if true // forward rendering

    private func setupSceneGraph() -> MTLPixelFormat {
        configureRootNode(children: [makeForwardPMXNode()])
        return .bgra8Unorm
    }

    private func makeForwardPMXNode() -> Node {
        let node = Node()
        pmxUpdater = makePMXUpdater()
        node.updater = pmxUpdater
        node.drawer = PMXDrawer(pmxObj: miku, device: device!)
        node.pass = ForwardRenderPass(view: self)
        return node
    }

    #else // deferred rendering

    private func setupSceneGraph() -> MTLPixelFormat {
        configureRootNode(children: [makeDeferredSceneNode()])
        return .bgra8Unorm
    }

    private func makeDeferredSceneNode() -> Node {
        let shadowPass = ShadowPass(device: device!)
        let node = Node()
        pmxUpdater = makePMXUpdater()
        node.updater = pmxUpdater
        node.children = [
            makeShadowNode(pass: shadowPass),
            makeGBufferNode(shadowPass: shadowPass),
            makeWireframeNode()
        ]
        return node
    }

    private func makeShadowNode(pass shadowPass: ShadowPass) -> Node {
        let node = Node()
        node.pass = shadowPass
        node.drawer = PMXShadowDrawer(pmxObj: miku)
        return node
    }

    private func makeGBufferNode(shadowPass: ShadowPass) -> Node {
        let node = Node()
        node.pass = GBufferPass(view: self)
        node.children = [
            makePMXGBufferNode(shadowTexture: shadowPass.shadowTexture),
            makePointLightNode()
        ]
        return node
    }

    private func makePMXGBufferNode(shadowTexture: MTLTexture) -> Node {
        let node = Node()
        node.drawer = PMXGBufferDrawer(
            device: device!,
            pmxObj: miku,
            shadowTexture: shadowTexture)
        return node
    }

    private func makePointLightNode() -> Node {
        let node = Node()
        node.drawer = PointLightDrawer(device: device!, lightCount: 1)
        return node
    }

    private func makeWireframeNode() -> Node {
        let node = Node()
        node.pass = WireframePass(device: device!)
        node.drawer = WireFrameDrawer(device: device!)
        return node
    }

    #endif

    // MARK: UI Event Handlers

    @objc func handlePan(_ recognize: UIPanGestureRecognizer) {
        let t = recognize.translation(in: self)
        let dx = Float(t.x)
        let dy = Float(t.y)
        if dx == 0 && dy == 0 {
            return
        }
        if recognize.numberOfTouches == 1 {
            let len = sqrt(dx * dx + dy * dy)
            let rad = len / 500 * Float.pi
            cameraUpdater.rot = cameraUpdater.rot.mul(
                GLKQuaternionMakeWithAngleAndVector3Axis(rad, GLKVector3Make(dy / len, dx / len, 0)))
        } else if recognize.numberOfTouches == 2 {
            let dX = cameraUpdater.viewMatrix.ixAxis().mul(-dx / 10)
            let dY = cameraUpdater.viewMatrix.iyAxis().mul(dy / 10)
            cameraUpdater.pos = cameraUpdater.pos.add(dX).add(dY)
        }

        recognize.setTranslation(CGPoint(x: 0, y: 0), in: self)
    }

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        if sender.state == .ended {
            cameraUpdater.rot = GLKQuaternionIdentity
            cameraUpdater.pos = InitialCameraPosition
        }
    }

    @objc func handlePinch(_ recognize: UIPinchGestureRecognizer) {
        let v = Float(recognize.velocity)
        let dz = -v * 0.5
        let dZ = cameraUpdater.viewMatrix.izAxis().mul(dz)
        cameraUpdater.pos = cameraUpdater.pos.add(dZ)
        recognize.scale = 1
    }

    @objc func handleRotate(_ recognize: UIRotationGestureRecognizer) {
        let v = Float(recognize.velocity)
        let rad = v * 0.05
        cameraUpdater.rot = cameraUpdater.rot.mul(
            GLKQuaternionMakeWithAngleAndVector3Axis(rad, GLKVector3Make(0, 0, 1)))
        recognize.rotation = 0
    }

    // MARK: Loop

    private func makePMXUpdater() -> PMXUpdater {
        return PMXUpdater(pmxObj: miku)
    }

    private func loadPMXResource() -> PMX {
        return LoadPMD("data/mmd/Alicia_solid")
    }

    private func loadVMDResource() -> VMD {
        return LoadVMD("data/vmd/2分ループステップ17")
    }

    private func makePMXObject(pmx: PMX, vmd: VMD) -> PMXObject {
        return PMXObject(device: device!, pmx: pmx, vmd: vmd)
    }

    private func loadSceneResources() {
        pmx = loadPMXResource()
        vmd = loadVMDResource()
        miku = makePMXObject(pmx: pmx!, vmd: vmd)
    }

    /// `MMDView` が window に乗ったタイミングで、描画レイヤーと scene graph の初期化を束ねる。
    /// UIKit lifecycle の入り口を 1 箇所へ寄せ、後で scene 再構成や `MTKView` 置換を試しやすくする。
    private func configureForWindow(_ window: UIWindow) {
        configureDisplayScale(for: window)
        configureRendererEndHandler()
        configureMetalLayer(pixelFormat: prepareScene())
        startDisplayLink()
    }

    private func configureDisplayScale(for window: UIWindow) {
        contentScaleFactor = window.screen.nativeScale
    }

    private func prepareScene() -> MTLPixelFormat {
        loadSceneResources()
        return setupSceneGraph()
    }

    private func configureRootNode(children: [Node]) {
        root.updater = cameraUpdater
        root.children = children
    }

    private func configureMetalLayer(pixelFormat: MTLPixelFormat) {
        if let metalLayer {
            metalLayer.pixelFormat = pixelFormat
            metalLayer.framebufferOnly = true
        }
    }

    private func configureRendererEndHandler() {
        renderer.setEndHandler({ [weak self] (_ renderer: Renderer) in
            self?.finishFrame(renderer: renderer)
        })
    }

    /// renderer 側で積み上げた command buffer を drawable 提示と一緒に閉じる。
    /// present / commit の最終段だけを `MMDView` に残し、renderer 本体は encode に集中させる。
    private func finishFrame(renderer: Renderer) {
        if let drawable = currentDrawable {
            if let commandBuffer = renderer.commandBuffer {
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
            releaseCurrentDrawable()
        }
    }

    private func startDisplayLink() {
        timer = CADisplayLink(target: self, selector: #selector(MMDView.mainLoop(_:)))
        if #available(iOS 10.0, *) {
            timer.preferredFramesPerSecond = 30
        } else {
            timer.frameInterval = 2
        }
        timer.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }

    private func updateDrawableSizeIfNeeded() {
        guard layerSizeDidUpdate else {
            return
        }

        self.drawableSize = CGSize(
            width: self.bounds.size.width * contentScaleFactor,
            height: self.bounds.size.height * contentScaleFactor
        )

        renderer.reshape(self.bounds)
        layerSizeDidUpdate = false
    }

    private func elapsedTime(since displayLink: CADisplayLink) -> CFTimeInterval {
        if lastFrameTimestamp == 0.0 {
            lastFrameTimestamp = displayLink.timestamp
        }

        let elapsed = displayLink.timestamp - lastFrameTimestamp
        lastFrameTimestamp = displayLink.timestamp
        return elapsed
    }

    /// 現在の layer / renderer 状態で draw を進めてよいかを判定する。
    /// drawable サイズ 0 のフレームを早期 return して、Metal 側の invalid texture 作成を避ける。
    private func isReadyToDrawCurrentFrame() -> Bool {
        return drawableSize.width > 0 && drawableSize.height > 0
    }

    private func drawCurrentFrame(elapsed: CFTimeInterval) {
        traverser.update(elapsed, node: root)
        traverser.draw(root)
    }

    @objc func mainLoop(_ displayLink: CADisplayLink) {
        let elapsed = elapsedTime(since: displayLink)

        updateDrawableSizeIfNeeded()

        guard isReadyToDrawCurrentFrame() else {
            return
        }

        drawCurrentFrame(elapsed: elapsed)
    }
}
