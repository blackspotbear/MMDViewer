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

func FKSolver(postures: [Posture], curveTies: [CurveTie], frameNum: Int) {
    for i in 0..<postures.count {
        let q_and_pos = InterpolateKeyFrame(curveTies[i], frameNum: frameNum)
        
        postures[i].q = q_and_pos.0 ?? GLKQuaternionIdentity
        
        // regard VMS's positon value as relative to bone's initial position
        postures[i].pos = postures[i].bone.pos.add(q_and_pos.1 ?? GLKVector3Make(0, 0, 0))
        
        postures[i].updateTransformMatrix(postures)
    }
}
