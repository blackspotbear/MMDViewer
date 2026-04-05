import Foundation
import GLKit
import simd

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

    func scale(_ x: Float, y: Float, z: Float) -> GLKMatrix4 {
        return GLKMatrix4Scale(self, x, y, z)
    }

    func rotateAroundX(_ x: Float, y: Float, z: Float) -> GLKMatrix4 {
        let rx = GLKMatrix4Rotate(self, x, 1, 0, 0)
        let ry = GLKMatrix4Rotate(  rx, y, 0, 1, 0)
        let rz = GLKMatrix4Rotate(  ry, z, 0, 0, 1)
        return rz
    }

    func translate(_ x: Float, y: Float, z: Float) -> GLKMatrix4 {
        return GLKMatrix4Translate(self, x, y, z)
    }

    func multiply(_ other: GLKMatrix4) -> GLKMatrix4 {
        return GLKMatrix4Multiply(self, other)
    }

    func multiplyLeft(_ other: GLKMatrix4) -> GLKMatrix4 {
        return GLKMatrix4Multiply(other, self)
    }

    func transpose() -> GLKMatrix4 {
        return GLKMatrix4Transpose(self)
    }

    func translate() -> GLKVector3 {
        return GLKVector3Make(self.m30, self.m31, self.m32)
    }

    func multiplyVector4(_ other: GLKVector4) -> GLKVector4 {
        return GLKMatrix4MultiplyVector4(self, other)
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
