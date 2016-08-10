import Foundation
import GLKit

@objc
protocol PhysicsSolving {
    var rigidBodies: [RigidBody] { get }
    var constraints: [Constraint] { get }
    func build(_ rigidBodies: [RigidBody], constraints: [Constraint], bones: [Bone])
    func move(_ boneIndex: Int, rot: GLKQuaternion, pos: GLKVector3)
    func getTransform(_ boneIndex: Int, rot: UnsafeMutablePointer<GLKQuaternion>, pos: UnsafeMutablePointer<GLKVector3>)
    func step()
}
