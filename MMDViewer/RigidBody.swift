import Foundation
import GLKit

class RigidBody: NSObject {
    var name: String
    var nameE: String

    var boneIndex: Int

    var groupID: UInt8
    var groupFlag: UInt16

    var shapeType: UInt8
    var size: GLKVector3

    var pos: GLKVector3
    var rot: GLKVector3

    var mass: Float
    var linearDamping: Float
    var angularDamping: Float
    var restitution: Float
    var friction: Float

    var type: UInt8

    init(name: String, nameE: String, boneIndex: Int, groupID: UInt8, groupFlag: UInt16, shapeType: UInt8, size: GLKVector3, pos: GLKVector3, rot: GLKVector3, mass: Float, linearDamping: Float, angularDamping: Float, restitution: Float, friction: Float, type: UInt8) {
        self.name = name
        self.nameE = nameE
        self.boneIndex = boneIndex
        self.groupID = groupID
        self.groupFlag = groupFlag
        self.shapeType = shapeType
        self.size = size
        self.pos = pos
        self.rot = rot
        self.mass = mass
        self.linearDamping = linearDamping
        self.angularDamping = angularDamping
        self.restitution = restitution
        self.friction = friction
        self.type = type
    }
}
