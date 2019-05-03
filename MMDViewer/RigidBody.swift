import Foundation
import GLKit

class RigidBody: NSObject {
    var name: String
    var nameE: String

    @objc var boneIndex: Int

    @objc var groupID: UInt8
    @objc var groupFlag: UInt16

    @objc var shapeType: UInt8
    @objc var size: GLKVector3

    @objc var pos: GLKVector3
    @objc var rot: GLKVector3

    @objc var mass: Float
    @objc var linearDamping: Float
    @objc var angularDamping: Float
    @objc var restitution: Float
    @objc var friction: Float

    @objc var type: UInt8

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
