import Foundation
import GLKit

typealias Color = GLKVector4

extension GLKVector4 {
    init(other: GLKVector4) {
        self.v = other.v
    }

    init(_ r: Float, _ g: Float, _ b: Float, _ a: Float) {
        self = GLKVector4Make(r, g, b, a)
    }

    func sub(_ other: GLKVector4) -> GLKVector4 {
        return GLKVector4Subtract(self, other)
    }

    func toGLKVector3() -> GLKVector3 {
        return GLKVector3Make(x, y, z)
    }
}
