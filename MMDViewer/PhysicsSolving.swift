import Foundation

@objc
protocol PhysicsSolving {
    func build(rigidBodies: [RigidBodyWrapper], joints: [JointWrapper])
}