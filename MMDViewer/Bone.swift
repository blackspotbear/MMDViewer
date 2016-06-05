import Foundation
import GLKit

struct BoneFlag: OptionSetType {
    let rawValue: UInt16
    
    static let ParentBoneIndex      = BoneFlag(rawValue: 0x0001)
    static let CanRotate            = BoneFlag(rawValue: 0x0002)
    static let CanTranslate         = BoneFlag(rawValue: 0x0004)
    static let Hyouzi               = BoneFlag(rawValue: 0x0008)
    static let Editable             = BoneFlag(rawValue: 0x0010)
    static let InverseKinematics    = BoneFlag(rawValue: 0x0020)
    static let LocalAdd             = BoneFlag(rawValue: 0x0080)
    static let RotationAdd          = BoneFlag(rawValue: 0x0100)
    static let TranslationAdd       = BoneFlag(rawValue: 0x0200)
    static let FixAxis              = BoneFlag(rawValue: 0x0400)
    static let LocalAxis            = BoneFlag(rawValue: 0x0800)
    static let DeformAfterPhysics   = BoneFlag(rawValue: 0x1000)
    static let DeformExternalParent = BoneFlag(rawValue: 0x2000)
}

struct IKLink {
    var boneIndex: Int
    var angularLimit: Bool
    var angularLimitMin: GLKVector3
    var angularLimitMax: GLKVector3
}

class Bone: NSObject {
    var name: String
    var nameE: String
    
    var pos: GLKVector3
    var parentBoneIndex: Int
    var deformLayer: Int32
    
    var bitFlag: BoneFlag
    
    var childOffset: GLKVector3
    var childBoneIndex: Int
    
    var affectingParentBoneIndex: Int
    var affectingRate: Float
    
    var fixAxis: GLKVector3

    var xAxis: GLKVector3
    var zAxis: GLKVector3
    
    var key: Int32
    
    var ikTargetBoneIndex: Int
    var ikLoopCount: Int32
    var ikAngularLimit: Float
    var ikLinks: [IKLink]
}