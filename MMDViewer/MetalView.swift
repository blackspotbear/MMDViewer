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

    /// `MTKView` へ寄せたので drawable の寿命管理は view 本体に任せる。
    /// 既存 call site を保つため、この互換 API は no-op として残す。
    func releaseCurrentDrawable() {}

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
