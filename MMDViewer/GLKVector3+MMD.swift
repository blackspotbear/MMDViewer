import Foundation
import GLKit
import simd

extension GLKVector3 {
    init(glkv4: GLKVector4) {
        self = GLKVector3Make(glkv4.x, glkv4.y, glkv4.z)
    }

    init(simd value: SIMD3<Float>) {
        self = GLKVector3Make(value.x, value.y, value.z)
    }

    var simdValue: SIMD3<Float> {
        SIMD3(x, y, z)
    }

    func add(_ rhs: GLKVector3) -> GLKVector3 {
        GLKVector3(simd: simdValue + rhs.simdValue)
    }

    func sub(_ rhs: GLKVector3) -> GLKVector3 {
        GLKVector3(simd: simdValue - rhs.simdValue)
    }

    func len() -> Float {
        simd_length(simdValue)
    }

    func mul(_ s: Float) -> GLKVector3 {
        GLKVector3(simd: simdValue * s)
    }

    func normal() -> GLKVector3 {
        return x != 0 || y != 0 || z != 0 ? GLKVector3(simd: simd_normalize(simdValue)) : self
    }

    func outer(_ rhs: GLKVector3) -> GLKVector3 {
        GLKVector3(simd: simd_cross(simdValue, rhs.simdValue))
    }

    func inner(_ rhs: GLKVector3) -> Float {
        simd_dot(simdValue, rhs.simdValue)
    }

    func toGLKVector4() -> GLKVector4 {
        return GLKVector4Make(x, y, z, 1)
    }
}

extension GLKVector3: @retroactive CustomStringConvertible {
    public var description: String { return String(format: "(%f,%f,%f)", x, y, z) }

    func dot(_ other: GLKVector3) -> Float {
        simd_dot(simdValue, other.simdValue)
    }

    func cross(_ other: GLKVector3) -> GLKVector3 {
        GLKVector3(simd: simd_cross(simdValue, other.simdValue))
    }
}
