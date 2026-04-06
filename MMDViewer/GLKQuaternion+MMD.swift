import Foundation
import GLKit
import simd

/// 呼び出し側の型を維持したまま、クォータニオン演算だけ `simd_quatf` へ寄せる。
extension GLKQuaternion: @retroactive CustomStringConvertible {
    public var description: String {
        return String(format: "(%f,%f,%f,%f)", x, y, z, w)
    }

    init(simd quaternion: simd_quatf) {
        let vector = quaternion.vector
        self = GLKQuaternionMake(vector.x, vector.y, vector.z, vector.w)
    }

    var simdQuaternion: simd_quatf {
        simd_quatf(vector: simd_float4(x, y, z, w))
    }

    init(other: GLKQuaternion) {
        self.init()
        self.q = other.q
    }

    func inverse() -> GLKQuaternion {
        GLKQuaternion(simd: simd_inverse(simdQuaternion))
    }

    /// 入力の `w` は位置ベクトルや属性値の意味を壊さないよう保持する。
    func rotate(_ other: GLKVector4) -> GLKVector4 {
        let rotated = simd_act(simdQuaternion, SIMD3(other.x, other.y, other.z))
        return GLKVector4Make(rotated.x, rotated.y, rotated.z, other.w)
    }

    func rotate(_ other: GLKVector3) -> GLKVector3 {
        GLKVector3(simd: simd_act(simdQuaternion, other.simdValue))
    }

    func mul(_ other: GLKQuaternion) -> GLKQuaternion {
        GLKQuaternion(simd: simd_mul(simdQuaternion, other.simdQuaternion))
    }

    func slerp(_ other: GLKQuaternion, t: Float) -> GLKQuaternion {
        GLKQuaternion(simd: simd_slerp(simdQuaternion, other.simdQuaternion, t))
    }
}
