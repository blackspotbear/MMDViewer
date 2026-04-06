import Foundation
import GLKit
import simd

/// `GLKMatrix4` を大量に抱える既存コードから段階的に離脱するための橋渡し層。
/// factory 系を `simd` に寄せつつ、乗算順序が絡む helper は当面 GLKit 実装を維持する。
/// `simd_mul` をそのまま使うと GLKit のベクトル適用規約とずれる箇所があるため、
/// 互換テストで縛れていない経路は慎重に残す。
extension GLKMatrix4: @retroactive CustomStringConvertible {
    public var description: String {
        return String(
            format: "|%f,%f,%f,%f|\n|%f,%f,%f,%f|\n|%f,%f,%f,%f|\n|%f,%f,%f,%f|",
            m00, m10, m20, m30,
            m01, m11, m21, m31,
            m02, m12, m22, m32,
            m03, m13, m23, m33
        )
    }

    init(other: GLKMatrix4) {
        self.init()
        self.m = other.m
    }

    init(simd matrix: simd_float4x4) {
        self = GLKMatrix4Make(
            matrix.columns.0.x, matrix.columns.1.x, matrix.columns.2.x, matrix.columns.3.x,
            matrix.columns.0.y, matrix.columns.1.y, matrix.columns.2.y, matrix.columns.3.y,
            matrix.columns.0.z, matrix.columns.1.z, matrix.columns.2.z, matrix.columns.3.z,
            matrix.columns.0.w, matrix.columns.1.w, matrix.columns.2.w, matrix.columns.3.w
        )
    }

    var simdMatrix: simd_float4x4 {
        simd_float4x4(
            SIMD4(m00, m10, m20, m30),
            SIMD4(m01, m11, m21, m31),
            SIMD4(m02, m12, m22, m32),
            SIMD4(m03, m13, m23, m33)
        )
    }

    static func translation(_ x: Float, _ y: Float, _ z: Float) -> GLKMatrix4 {
        let matrix = simd_float4x4(rows: [
            SIMD4(1, 0, 0, 0),
            SIMD4(0, 1, 0, 0),
            SIMD4(0, 0, 1, 0),
            SIMD4(x, y, z, 1)
        ])
        return GLKMatrix4(simd: matrix)
    }

    static func scale(_ x: Float, _ y: Float, _ z: Float) -> GLKMatrix4 {
        var matrix = matrix_identity_float4x4
        matrix.columns.0.x = x
        matrix.columns.1.y = y
        matrix.columns.2.z = z
        return GLKMatrix4(simd: matrix)
    }

    static func rotation(_ quaternion: GLKQuaternion) -> GLKMatrix4 {
        GLKMatrix4(simd: simd_transpose(simd_float4x4(quaternion.simdQuaternion)))
    }

    static func rotation(angle radians: Float, axis: GLKVector3) -> GLKMatrix4 {
        let normalizedAxis = axis.normal()
        let quaternion = simd_quatf(angle: radians, axis: normalizedAxis.simdValue)
        return GLKMatrix4(simd: simd_transpose(simd_float4x4(quaternion)))
    }

    static func lookAt(eye: GLKVector3, center: GLKVector3, up: GLKVector3) -> GLKMatrix4 {
        let forward = eye.sub(center).normal()
        let right = up.outer(forward).normal()
        let cameraUp = forward.outer(right)

        let matrix = simd_float4x4(rows: [
            SIMD4(right.x, cameraUp.x, forward.x, 0),
            SIMD4(right.y, cameraUp.y, forward.y, 0),
            SIMD4(right.z, cameraUp.z, forward.z, 0),
            SIMD4(-right.inner(eye), -cameraUp.inner(eye), -forward.inner(eye), 1)
        ])
        return GLKMatrix4(simd: matrix)
    }

    static func perspective(fovyRadians: Float, aspect: Float, near: Float, far: Float) -> GLKMatrix4 {
        let yScale = 1 / tan(fovyRadians * 0.5)
        let xScale = yScale / aspect
        let zRange = far - near

        let matrix = simd_float4x4(rows: [
            SIMD4(xScale, 0, 0, 0),
            SIMD4(0, yScale, 0, 0),
            SIMD4(0, 0, -(far + near) / zRange, -1),
            SIMD4(0, 0, -(2 * far * near) / zRange, 0)
        ])
        return GLKMatrix4(simd: matrix)
    }

    /// Metal NDC に合わせた right-handed off-center orthographic projection.
    static func orthographicOffCenter(left: Float, right: Float,
                                      bottom: Float, top: Float,
                                      near: Float, far: Float) -> GLKMatrix4 {
        let sLength = 1.0 / (right - left)
        let sHeight = 1.0 / (top - bottom)
        let sDepth = 1.0 / (far - near)

        let matrix = simd_float4x4(rows: [
            SIMD4(2.0 * sLength, 0.0, 0.0, 0.0),
            SIMD4(0.0, 2.0 * sHeight, 0.0, 0.0),
            SIMD4(0.0, 0.0, -sDepth, 0.0),
            SIMD4(-sLength * (left + right), -sHeight * (top + bottom), -sDepth * near, 1.0)
        ])
        return GLKMatrix4(simd: matrix)
    }

    func scale(_ x: Float, y: Float, z: Float) -> GLKMatrix4 {
        multiply(GLKMatrix4.scale(x, y, z))
    }

    func rotateAroundX(_ x: Float, y: Float, z: Float) -> GLKMatrix4 {
        let rx = multiply(GLKMatrix4.rotation(angle: x, axis: GLKVector3Make(1, 0, 0)))
        let ry = rx.multiply(GLKMatrix4.rotation(angle: y, axis: GLKVector3Make(0, 1, 0)))
        return ry.multiply(GLKMatrix4.rotation(angle: z, axis: GLKVector3Make(0, 0, 1)))
    }

    func translate(_ x: Float, y: Float, z: Float) -> GLKMatrix4 {
        multiply(GLKMatrix4.translation(x, y, z))
    }

    func multiply(_ other: GLKMatrix4) -> GLKMatrix4 {
        GLKMatrix4Multiply(self, other)
    }

    func multiplyLeft(_ other: GLKMatrix4) -> GLKMatrix4 {
        GLKMatrix4Multiply(other, self)
    }

    func transpose() -> GLKMatrix4 {
        GLKMatrix4(simd: simd_transpose(simdMatrix))
    }

    func translate() -> GLKVector3 {
        return GLKVector3Make(self.m30, self.m31, self.m32)
    }

    func multiplyVector4(_ other: GLKVector4) -> GLKVector4 {
        GLKVector4(simd: simd_mul(other.simdValue, simdMatrix))
    }

    func xAxis() -> GLKVector3 {
        return GLKVector3Make(self.m00, self.m01, self.m02)
    }

    func yAxis() -> GLKVector3 {
        return GLKVector3Make(self.m10, self.m11, self.m12)
    }

    func zAxis() -> GLKVector3 {
        return GLKVector3Make(self.m20, self.m21, self.m22)
    }

    func ixAxis() -> GLKVector3 {
        return GLKVector3Make(self.m00, self.m10, self.m20)
    }

    func iyAxis() -> GLKVector3 {
        return GLKVector3Make(self.m01, self.m11, self.m21)
    }

    func izAxis() -> GLKVector3 {
        return GLKVector3Make(self.m02, self.m12, self.m22)
    }
}
