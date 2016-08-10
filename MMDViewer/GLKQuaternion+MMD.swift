import Foundation
import GLKit

extension GLKQuaternion: CustomStringConvertible {
    public var description: String {
        return String(format: "(%f,%f,%f,%f)", x, y, z, w)
    }

    init(other: GLKQuaternion) {
        self.q = other.q
    }

    func inverse() -> GLKQuaternion {
        return GLKQuaternionInvert(self)
    }

    func rotate(_ other: GLKVector4) -> GLKVector4 {
        return GLKQuaternionRotateVector4(self, other)
    }

    func rotate(_ other: GLKVector3) -> GLKVector3 {
        return GLKQuaternionRotateVector3(self, other)
    }

    func mul(_ other: GLKQuaternion) -> GLKQuaternion {
        return GLKQuaternionMultiply(self, other)
    }
}
