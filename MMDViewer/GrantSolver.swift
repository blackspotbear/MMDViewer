import Foundation
import GLKit

func GrantSolver(_ postures: [Posture]) {
    for posture in postures {
        var dirty = false
        if posture.bone.bitFlag.contains(.RotationAdd) {
            let pb = postures[posture.bone.affectingParentBoneIndex]
            let q = GLKQuaternionIdentity.slerp(pb.q, t: posture.bone.affectingRate)
            posture.q = posture.q.mul(q)
            dirty = true
        }
        if posture.bone.bitFlag.contains(.TranslationAdd) {
            let pb = postures[posture.bone.affectingParentBoneIndex]
            posture.pos = pb.pos
            dirty = true
        }
        if dirty {
            posture.updateTransformMatrix(postures)
        }
    }
}
