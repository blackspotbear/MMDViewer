import Foundation
import GLKit

func GrantSolver(postures: [Posture]) {
    for posture in postures {
        var dirty = false
        if posture.bone.bitFlag.contains(.RotationAdd) {
            let pb = postures[posture.bone.affectingParentBoneIndex]
            let q = GLKQuaternionSlerp(GLKQuaternionIdentity, pb.q, posture.bone.affectingRate)
            posture.q = posture.q.mul(q)
            dirty = true
        }
        if posture.bone.bitFlag.contains(.TranslationAdd) {
            let pb = postures[posture.bone.affectingParentBoneIndex]
            posture.pos = pb.pos
            dirty = true
        }
        if dirty {
            posture.updateTransformMatrix(postures);
        }
    }
}
