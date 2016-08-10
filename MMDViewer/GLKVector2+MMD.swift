import Foundation
import GLKit

typealias UV = GLKVector2

extension GLKVector2: CustomStringConvertible {
    public var description: String { return String(format: "(%f,%f)", u, v) }

    var u: Float { return self.s }
    var v: Float { return self.t }

    init(_ u: Float, _ v: Float) {
        self = GLKVector2Make(u, v)
    }
}
