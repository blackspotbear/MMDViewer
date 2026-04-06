import Foundation
import UIKit
import Metal
import QuartzCore

/// `melt` の UIView 側エントリポイント。
/// CAMetalLayer の所有と current drawable の取得だけを担当し、描画内容の管理は pass / renderer 側へ委ねる。
class MetalView: UIView {
    var device: MTLDevice?

    var currentDrawable: CAMetalDrawable? {
        if _currentDrawable == nil {
            _currentDrawable = nextDrawable()
        }
        return _currentDrawable
    }

    var drawableSize: CGSize {
        set (v) {
            if let metalLayer = metalLayer, v.width > 0, v.height > 0 {
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        initMetalLayer()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initMetalLayer()
    }

    func releaseCurrentDrawable() {
        _currentDrawable = nil
    }

    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }

    /// drawable 取得失敗は render loop 全体の前提崩壊なので、ここで早めに止める。
    private func nextDrawable() -> CAMetalDrawable {
        guard let metalLayer = metalLayer else {
            fatalError("failed to get a drawable")
        }
        guard let drawable = metalLayer.nextDrawable() else {
            fatalError("failed to acquire next drawable")
        }
        return drawable
    }

    private final func initMetalLayer() {
        guard let metalLayer = self.layer as? CAMetalLayer else {
            return
        }

        let device = makeSystemDefaultDevice()
        configure(metalLayer: metalLayer, device: device)

        self.device = device
        self.metalLayer = metalLayer
    }

    private func makeSystemDefaultDevice() -> MTLDevice {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("can't create system default device")
        }
        return device
    }

    /// `MetalView` が直接持つべき layer 初期設定だけをまとめる。
    /// pixel format や framebufferOnly のような描画方針は `MMDView` / pass 側で上書きする。
    private func configure(metalLayer: CAMetalLayer, device: MTLDevice) {
        metalLayer.device = device
        metalLayer.frame = bounds
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalLayer?.frame = bounds
    }
}
