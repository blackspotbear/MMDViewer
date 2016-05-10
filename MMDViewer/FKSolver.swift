import Foundation
import GLKit

func FKSolver(postures: [Posture], vmd: VMD, frameNum: Int) {
    for posture in postures {
        let q_and_pos = vmd.getTransformation(posture.bone.name, frameNum: frameNum)
        
        posture.q = q_and_pos.0 ?? GLKQuaternionIdentity
        
        // regard VMS's positon value as relative to bone's initial position
        posture.pos = posture.bone.pos.add(q_and_pos.1 ?? GLKVector3Make(0, 0, 0))
        
        posture.updateTransformMatrix(postures)
    }
}
