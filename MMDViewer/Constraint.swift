import Foundation
import GLKit

class Constraint: NSObject {
    var name: String
    var nameE: String

    var type: UInt8

    @objc var rigidAIndex: Int
    @objc var rigidBIndex: Int

    @objc var pos: GLKVector3
    @objc var rot: GLKVector3

    @objc var linearLowerLimit: GLKVector3
    @objc var linearUpperLimit: GLKVector3
    @objc var angularLowerLimit: GLKVector3
    @objc var angularUpperLimit: GLKVector3

    @objc var linearSpringStiffness: GLKVector3
    @objc var angularSpringStiffness: GLKVector3

    init(name: String, nameE: String, type: UInt8, rigidAIndex: Int, rigidBIndex: Int, pos: GLKVector3, rot: GLKVector3, linearLowerLimit: GLKVector3, linearUpperLimit: GLKVector3, angularLowerLimit: GLKVector3, angularUpperLimit: GLKVector3, linearSpringStiffness: GLKVector3, angularSpringStiffness: GLKVector3) {
        self.name = name
        self.nameE = nameE
        self.type = type
        self.rigidAIndex = rigidAIndex
        self.rigidBIndex = rigidBIndex
        self.pos = pos
        self.rot = rot
        self.linearLowerLimit = linearLowerLimit
        self.linearUpperLimit = linearUpperLimit
        self.angularLowerLimit = angularLowerLimit
        self.angularUpperLimit = angularUpperLimit
        self.linearSpringStiffness = linearSpringStiffness
        self.angularSpringStiffness = angularSpringStiffness
    }
}
