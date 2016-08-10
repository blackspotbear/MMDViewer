import Foundation
import GLKit

struct MaterialFlag: OptionSet {
    let rawValue: UInt8

    static let DrawBothSides      = MaterialFlag(rawValue: 1 << 0)
    static let DrawGroundShadow   = MaterialFlag(rawValue: 1 << 1)
    static let SelfShadowCaster   = MaterialFlag(rawValue: 1 << 2)
    static let SelfShadowReceiver = MaterialFlag(rawValue: 1 << 3)
    static let DrawEdge           = MaterialFlag(rawValue: 1 << 4)
}

struct Material {
    var name: String
    var nameE: String

    var diffuse: Color
    var specular: Color // a should be 1.0
    var specularPower: Float
    var ambient: Color // a should be 1.0

    var flag: MaterialFlag

    var edgeColor: Color
    var edgeSize: Float

    var textureIndex: Int
    var sphereTextureIndex: Int
    var sphereMode: UInt8

    var sharedToon: Bool
    var toonTextureIndex: Int

    var memo: String

    var vertexCount: Int32
}
