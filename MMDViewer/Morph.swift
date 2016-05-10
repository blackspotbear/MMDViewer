import Foundation
import GLKit

enum MorphType: Int {
    case Group = 0
    case Vertex
    case Bone
    case UV
    case UV1
    case UV2
    case UV3
    case UV4
    case Material
}

struct MorphGroup {
    var index: Int
    var ratio: Float
}

struct MorphVertex {
    var index: Int
    var trans: GLKVector3
}

struct MorphBone {
    var index: Int
    var trans: GLKVector3
    var rot: GLKQuaternion
}

struct MorphUV {
    var index: Int
    var trans: GLKVector4
}

struct MorphMaterial {
    var index: Int
    var opType: UInt8
    var diffuse: GLKVector4
    var specular: GLKVector3
    var shininess: Float
    var ambient: GLKVector3
    var edgeColor: GLKVector4
    var edgeSize: Float
    var textureColor: GLKVector4
    var sphereTextureColor: GLKVector4
    var toonTextureColor: GLKVector4
}

struct Morph {
    var name: String
    var nameE: String
    var panel: Int
    var type: MorphType
    var elements: [Any]
}
