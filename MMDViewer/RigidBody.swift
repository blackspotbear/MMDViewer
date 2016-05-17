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