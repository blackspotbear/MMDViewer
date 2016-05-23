import Foundation
import GLKit

struct RigidBody {
    var name: String
    var nameE: String
    
    var boneIndex: Int
    
    var group: UInt8
    var groupFlag: UInt16
    
    var shape: UInt8
    var size: GLKVector3
    
    var pos: GLKVector3
    var rot: GLKVector3
    
    var mass: Float
    var tdump: Float
    var rdump: Float
    var e: Float
    var u: Float
    
    var objType: UInt8
}

public class RigidBodyWrapper: NSObject {
    private let rigidBody: RigidBody
    
    var name: String { return rigidBody.name }
    var nameE: String { return rigidBody.nameE }
    var boneIndex: Int { return rigidBody.boneIndex }
    var group: UInt8 { return rigidBody.group }
    var groupFlag: UInt16 { return rigidBody.groupFlag }
    var shape: UInt8 { return rigidBody.shape }
    var size: GLKVector3 { return rigidBody.size }
    var pos: GLKVector3 { return rigidBody.pos }
    var rot: GLKVector3 { return rigidBody.rot }
    var mass: Float { return rigidBody.mass }
    var tdump: Float { return rigidBody.tdump }
    var rdump: Float { return rigidBody.rdump }
    var e: Float { return rigidBody.e }
    var u: Float { return rigidBody.u }
    var objType: UInt8 { return rigidBody.objType }
    
    init(rigidBody: RigidBody) {
        self.rigidBody = rigidBody
    }
}