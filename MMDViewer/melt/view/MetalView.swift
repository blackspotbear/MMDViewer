import Foundation
import UIKit
import Metal
import MetalKit
import QuartzCore

private struct MetalViewConfiguration {
    let device: MTLDevice
}

/// `melt` の UIView 側エントリポイント。
/// `MTKView` を substrate として使い、drawable と drawableSize の管理だけを担当する。
class MetalView: MTKView {
    private var cachedDrawable: CAMetalDrawable?

    private var metalLayer: CAMetalLayer? {
        return layer as? CAMetalLayer
    }

    override init(frame: CGRect, device: MTLDevice?) {
        let configuration = Self.makeConfiguration(device: device)
        super.init(frame: frame, device: configuration.device)
        configure(configuration)
    }

    required init(coder: NSCoder) {
        let configuration = Self.makeConfiguration(device: nil)
        super.init(coder: coder)
        self.device = configuration.device
        configure(configuration)
    }

    /// 1 フレーム中は同じ drawable を使い回し、present 後に明示的に破棄する。
    /// `MTKView.currentDrawable` を各所から直接読むと present 済み drawable を再利用しうるため、
    /// 既存 renderer 契約はこの互換 API に集約して守る。
    func acquireCurrentDrawable() -> CAMetalDrawable? {
        if let cachedDrawable {
            return cachedDrawable
        }

        let drawable = metalLayer?.nextDrawable()
        cachedDrawable = drawable
        return drawable
    }

    func releaseCurrentDrawable() {
        cachedDrawable = nil
    }

    private static func makeConfiguration(device: MTLDevice?) -> MetalViewConfiguration {
        if let device {
            return MetalViewConfiguration(device: device)
        }

        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("can't create system default device")
        }
        return MetalViewConfiguration(device: defaultDevice)
    }

    /// `MetalView` が直接持つべき view substrate の設定だけをここに閉じ込める。
    /// frame 駆動や scene graph は `MMDView` 側に残し、最小移行では自動描画も無効化しておく。
    private func configure(_ configuration: MetalViewConfiguration) {
        device = configuration.device
        framebufferOnly = true
        autoResizeDrawable = false
        isPaused = true
        enableSetNeedsDisplay = false
    }
}
