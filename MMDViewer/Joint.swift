import Foundation
import GLKit

struct Joint {
    var name: String
    var nameE: String
    
    var type: UInt8

    var rigidAIndex: Int
    var rigidBIndex: Int
    
    var pos: GLKVector3
    var rot: GLKVector3
    
    var linearLowerLimit: GLKVector3
    var linearUpperLimit: GLKVector3
    var angularLowerLimit: GLKVector3
    var angularUpperLimit: GLKVector3
    
    // btGeneric6DofSpringConstraint::setStiffness
    var linearSpringStiffness: GLKVector3
    var angularSpringStiffness: GLKVector3
}

public class JointWrapper: NSObject {
    private let joint: Joint
    
    var name: String { return joint.name }
    var nameE: String { return joint.nameE }
    var type: UInt8 { return joint.type }
    var rigidAIndex: Int { return joint.rigidAIndex }
    var rigidBIndex: Int { return joint.rigidBIndex }
    var pos: GLKVector3 { return joint.pos }
    var rot: GLKVector3 { return joint.rot }
    var linearLowerLimit: GLKVector3 { return joint.linearLowerLimit }
    var linearUpperLimit: GLKVector3 { return joint.linearUpperLimit }
    var angularLowerLimit: GLKVector3 { return joint.angularLowerLimit }
    var angularUpperLimit: GLKVector3 { return joint.angularUpperLimit }
    var linearSpringStiffness: GLKVector3 { return joint.linearSpringStiffness }
    var angularSpringStiffness: GLKVector3 { return joint.angularSpringStiffness }
    
    init(_ joint: Joint) {
        self.joint = joint
    }
}