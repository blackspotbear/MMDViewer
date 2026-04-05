import Foundation
import GLKit
import simd

typealias UV = GLKVector2

/// UV と補間制御点で使う 2 次元ベクトルの互換レイヤー。
/// 呼び出し側の型は維持しつつ、内部演算だけを `simd` へ寄せる。
extension GLKVector2: @retroactive CustomStringConvertible {
    public var description: String { return String(format: "(%f,%f)", u, v) }

    var u: Float { return self.s }
    var v: Float { return self.t }

    init(simd value: SIMD2<Float>) {
        self = GLKVector2Make(value.x, value.y)
    }

    var simdValue: SIMD2<Float> {
        SIMD2(x, y)
    }

    init(_ u: Float, _ v: Float) {
        self = GLKVector2Make(u, v)
    }
}
