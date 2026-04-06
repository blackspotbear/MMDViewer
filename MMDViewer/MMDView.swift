import Foundation
import UIKit
import GLKit
import Metal

let InitialCameraPosition = GLKVector3Make(0, 10, 20)

private struct MMDSceneResources {
    let pmx: PMX
    let vmd: VMD
    let pmxObject: PMXObject
}

private struct MMDSceneGraphConfiguration {
    let children: [Node]
    let pixelFormat: MTLPixelFormat
}

private struct MMDPreparedScene {
    let resources: MMDSceneResources
    let sceneGraph: MMDSceneGraphConfiguration
}

private struct MMDWindowConfiguration {
    let displayScale: CGFloat
    let preparedScene: MMDPreparedScene
    let preferredFramesPerSecond: Int
}

private struct MMDSceneApplication {
    let resources: MMDSceneResources
    let sceneGraph: MMDSceneGraphConfiguration
}

private struct MMDPreparedFrame {
    let elapsed: CFTimeInterval
    let layout: MMDDrawableLayout
}

private struct MMDFrameCompletion {
    let drawable: CAMetalDrawable
    let commandBuffer: MTLCommandBuffer
}

private struct MMDDrawableLayout {
    let drawableSize: CGSize
    let bounds: CGRect
}

private struct MMDDisplayLinkConfiguration {
    let preferredFramesPerSecond: Int
}

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
            markDrawableSizeNeedsUpdate()
        }
        get {
            return super.contentScaleFactor
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        markDrawableSizeNeedsUpdate()
    }

    private func markDrawableSizeNeedsUpdate() {
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

    private func makeSceneGraphConfiguration(pmxObject: PMXObject) -> MMDSceneGraphConfiguration {
        return MMDSceneGraphConfiguration(
            children: [makeForwardPMXNode(pmxObject: pmxObject)],
            pixelFormat: .bgra8Unorm)
    }

    private func makeForwardPMXNode(pmxObject: PMXObject) -> Node {
        let node = Node()
        pmxUpdater = makePMXUpdater(pmxObject: pmxObject)
        node.updater = pmxUpdater
        node.drawer = PMXDrawer(pmxObj: pmxObject, device: device!)
        node.pass = ForwardRenderPass(view: self)
        return node
    }

    #else // deferred rendering

    private func makeSceneGraphConfiguration(pmxObject: PMXObject) -> MMDSceneGraphConfiguration {
        return MMDSceneGraphConfiguration(
            children: [makeDeferredSceneNode(pmxObject: pmxObject)],
            pixelFormat: .bgra8Unorm)
    }

    private func makeDeferredSceneNode(pmxObject: PMXObject) -> Node {
        let shadowPass = ShadowPass(device: device!)
        let node = Node()
        pmxUpdater = makePMXUpdater(pmxObject: pmxObject)
        node.updater = pmxUpdater
        node.children = [
            makeShadowNode(pass: shadowPass, pmxObject: pmxObject),
            makeGBufferNode(shadowPass: shadowPass, pmxObject: pmxObject),
            makeWireframeNode()
        ]
        return node
    }

    private func makeShadowNode(pass shadowPass: ShadowPass, pmxObject: PMXObject) -> Node {
        let node = Node()
        node.pass = shadowPass
        node.drawer = PMXShadowDrawer(pmxObj: pmxObject)
        return node
    }

    private func makeGBufferNode(shadowPass: ShadowPass, pmxObject: PMXObject) -> Node {
        let node = Node()
        node.pass = GBufferPass(view: self)
        node.children = [
            makePMXGBufferNode(pmxObject: pmxObject, shadowTexture: shadowPass.shadowTexture),
            makePointLightNode()
        ]
        return node
    }

    private func makePMXGBufferNode(pmxObject: PMXObject, shadowTexture: MTLTexture) -> Node {
        let node = Node()
        node.drawer = PMXGBufferDrawer(
            device: device!,
            pmxObj: pmxObject,
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

    private func makePMXUpdater(pmxObject: PMXObject) -> PMXUpdater {
        return PMXUpdater(pmxObj: pmxObject)
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

    private func makeSceneResources() -> MMDSceneResources {
        let pmx = loadPMXResource()
        let vmd = loadVMDResource()
        return MMDSceneResources(
            pmx: pmx,
            vmd: vmd,
            pmxObject: makePMXObject(pmx: pmx, vmd: vmd))
    }

    private func storeSceneResources(_ resources: MMDSceneResources) {
        pmx = resources.pmx
        vmd = resources.vmd
        miku = resources.pmxObject
    }

    /// `MMDView` が window に乗ったタイミングで、描画レイヤーと scene graph の初期化を束ねる。
    /// UIKit lifecycle の入り口を 1 箇所へ寄せ、後で scene 再構成や `MTKView` 置換を試しやすくする。
    private func configureForWindow(_ window: UIWindow) {
        let configuration = makeWindowConfiguration(for: window)
        applyWindowConfiguration(configuration)
        configureRendererEndHandler()
        startDisplayLink(configuration: configuration)
    }

    private func makeWindowConfiguration(for window: UIWindow) -> MMDWindowConfiguration {
        return MMDWindowConfiguration(
            displayScale: window.screen.nativeScale,
            preparedScene: prepareScene(),
            preferredFramesPerSecond: 30)
    }

    private func applyWindowConfiguration(_ configuration: MMDWindowConfiguration) {
        contentScaleFactor = configuration.displayScale
        applyPreparedScene(configuration.preparedScene)
    }

    private func prepareScene() -> MMDPreparedScene {
        let resources = makeSceneResources()
        return MMDPreparedScene(
            resources: resources,
            sceneGraph: makeSceneGraphConfiguration(pmxObject: resources.pmxObject))
    }

    private func applyPreparedScene(_ scene: MMDPreparedScene) {
        applyScene(makeSceneApplication(scene))
    }

    private func makeSceneApplication(_ scene: MMDPreparedScene) -> MMDSceneApplication {
        return MMDSceneApplication(
            resources: scene.resources,
            sceneGraph: scene.sceneGraph)
    }

    private func applyScene(_ scene: MMDSceneApplication) {
        storeSceneResources(scene.resources)
        configureSceneGraph(scene.sceneGraph)
        configureMetalLayer(pixelFormat: scene.sceneGraph.pixelFormat)
    }

    private func configureSceneGraph(_ sceneGraph: MMDSceneGraphConfiguration) {
        root.updater = cameraUpdater
        root.children = sceneGraph.children
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
        guard let completion = currentFrameCompletion(renderer: renderer) else {
            return
        }

        completeFrame(completion)
        releaseCurrentDrawable()
    }

    private func currentFrameCompletion(renderer: Renderer) -> MMDFrameCompletion? {
        guard let drawable = currentDrawable,
              let commandBuffer = renderer.commandBuffer else {
            return nil
        }

        return MMDFrameCompletion(drawable: drawable, commandBuffer: commandBuffer)
    }

    private func completeFrame(_ completion: MMDFrameCompletion) {
        completion.commandBuffer.present(completion.drawable)
        completion.commandBuffer.commit()
    }

    private func startDisplayLink(configuration: MMDWindowConfiguration) {
        let displayLink = makeDisplayLink()
        configureDisplayLink(
            displayLink,
            configuration: makeDisplayLinkConfiguration(window: configuration))
        displayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
        timer = displayLink
    }

    private func makeDisplayLink() -> CADisplayLink {
        return CADisplayLink(target: self, selector: #selector(MMDView.mainLoop(_:)))
    }

    private func makeDisplayLinkConfiguration(window configuration: MMDWindowConfiguration) -> MMDDisplayLinkConfiguration {
        return MMDDisplayLinkConfiguration(
            preferredFramesPerSecond: configuration.preferredFramesPerSecond)
    }

    private func configureDisplayLink(_ displayLink: CADisplayLink, configuration: MMDDisplayLinkConfiguration) {
        if #available(iOS 10.0, *) {
            displayLink.preferredFramesPerSecond = configuration.preferredFramesPerSecond
        } else {
            displayLink.frameInterval = 2
        }
    }

    private func updateDrawableSizeIfNeeded() {
        guard layerSizeDidUpdate else {
            return
        }

        let layout = currentDrawableLayout()
        self.drawableSize = layout.drawableSize
        renderer.reshape(layout.bounds)
        layerSizeDidUpdate = false
    }

    private func currentDrawableLayout() -> MMDDrawableLayout {
        return MMDDrawableLayout(
            drawableSize: CGSize(
                width: self.bounds.size.width * contentScaleFactor,
                height: self.bounds.size.height * contentScaleFactor),
            bounds: self.bounds)
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
    private func isReadyToDrawCurrentFrame(layout: MMDDrawableLayout) -> Bool {
        return layout.drawableSize.width > 0 && layout.drawableSize.height > 0
    }

    private func drawPreparedFrame(_ frame: MMDPreparedFrame) {
        traverser.update(frame.elapsed, node: root)
        traverser.draw(root)
    }

    private func prepareCurrentFrame(_ displayLink: CADisplayLink) -> MMDPreparedFrame? {
        let elapsed = elapsedTime(since: displayLink)

        updateDrawableSizeIfNeeded()
        let layout = currentDrawableLayout()

        guard isReadyToDrawCurrentFrame(layout: layout) else {
            return nil
        }

        return MMDPreparedFrame(
            elapsed: elapsed,
            layout: layout)
    }

    @objc func mainLoop(_ displayLink: CADisplayLink) {
        guard let frame = prepareCurrentFrame(displayLink) else {
            return
        }

        drawPreparedFrame(frame)
    }
}
