import Foundation
import GLKit

struct PMXVertex {
    var v: GLKVector3
    var n: GLKVector3
    var uv: UV
    
    var euvs: [GLKVector4]
    
    var skinningMethod: UInt8
    var boneWeights: [Float]
    var boneIndices: [UInt16]
    
    func floatBuffer() -> [Float] {
        return [
             v.x,  v.y,  v.z,
             n.x,  n.y,  n.z,
            uv.u, uv.v
        ]
    }
    
    static var packedSize: Int {
        // see struct VertexIn
        return 12 + 12 + 8 + 16 + 8
    }
}
