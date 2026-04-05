import Foundation
import GLKit
import simd

typealias Color = GLKVector4

extension GLKVector4 {
    init(simd value: SIMD4<Float>) {
        self = GLKVector4Make(value.x, value.y, value.z, value.w)
    }

    var simdValue: SIMD4<Float> {
        SIMD4(x, y, z, w)
    }

    init(other: GLKVector4) {
        self.init()
        self.v = other.v
    }

    init(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        self = GLKVector4Make(r, g, b, a)
    }

    func sub(_ other: GLKVector4) -> GLKVector4 {
        GLKVector4(simd: simdValue - other.simdValue)
    }

    func toGLKVector3() -> GLKVector3 {
        return GLKVector3Make(x, y, z)
    }
}
