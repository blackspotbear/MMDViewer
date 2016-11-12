import Foundation
import UIKit
import Metal

class MetalView: UIView {
    var device: MTLDevice?

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
}
