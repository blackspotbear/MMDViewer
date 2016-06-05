import Foundation
import GLKit

@objc
protocol PhysicsSolving {
    var rigidBodies: [RigidBody] { get }
    var constraints: [Constraint] { get }
    func build(rigidBodies: [RigidBody], constraints: [Constraint], bones: [Bone])
    func move(boneIndex: Int, rot: GLKQuaternion, pos: GLKVector3)
    func getTransform(boneIndex: Int, rot: UnsafeMutablePointer<GLKQuaternion>, pos: UnsafeMutablePointer<GLKVector3>)
    func step();
}