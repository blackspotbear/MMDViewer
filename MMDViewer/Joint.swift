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