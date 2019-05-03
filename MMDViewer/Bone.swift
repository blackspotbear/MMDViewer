import Foundation
import GLKit

struct BoneFlag: OptionSet {
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

    @objc var pos: GLKVector3
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

    init(name: String, nameE: String, pos: GLKVector3, parentBoneIndex: Int, deformLayer: Int32, bitFlag: BoneFlag, childOffset: GLKVector3, childBoneIndex: Int, affectingParentBoneIndex: Int, affectingRate: Float, fixAxis: GLKVector3, xAxis: GLKVector3, zAxis: GLKVector3, key: Int32, ikTargetBoneIndex: Int, ikLoopCount: Int32, ikAngularLimit: Float, ikLinks: [IKLink]) {
        self.name = name
        self.nameE = nameE
        self.pos = pos
        self.parentBoneIndex = parentBoneIndex
        self.deformLayer = deformLayer
        self.bitFlag = bitFlag
        self.childOffset = childOffset
        self.childBoneIndex = childBoneIndex
        self.affectingParentBoneIndex = affectingParentBoneIndex
        self.affectingRate = affectingRate
        self.fixAxis = fixAxis
        self.xAxis = xAxis
        self.zAxis = zAxis
        self.key = key
        self.ikTargetBoneIndex = ikTargetBoneIndex
        self.ikLoopCount = ikLoopCount
        self.ikAngularLimit = ikAngularLimit
        self.ikLinks = ikLinks
    }
}
