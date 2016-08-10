import Foundation
import GLKit

extension GLKMatrix4: CustomStringConvertible {
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
        self.m = other.m
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

    func raw() -> UnsafeRawPointer {
        // see https://lists.swift.org/pipermail/swift-dev/Week-of-Mon-20151214/000404.html
        // copy self not to make raw() mutating
        var mutatingSelf = self
        // NOTE: ! return a pointer to a local variable
        return withUnsafePointer(to: &mutatingSelf) { UnsafeRawPointer($0) }
    }

    // mutating version
    mutating func raw_mutating() -> UnsafeRawPointer {
        return withUnsafePointer(to: &self) { UnsafeRawPointer($0) }
    }

    func transpose() -> GLKMatrix4 {
        return GLKMatrix4Transpose(self)
    }

    func translate() -> GLKVector4 {
        return GLKVector4Make(self.m30, self.m31, self.m32, self.m33)
    }

    func multiplyVector4(_ other: GLKVector4) -> GLKVector4 {
        return GLKMatrix4MultiplyVector4(self, other)
    }
}
