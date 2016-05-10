import Foundation
import GLKit

// CCDIKSolver
// see:
// https://sites.google.com/site/auraliusproject/ccd-algorithm
// https://www.youtube.com/watch?v=MvuO9ZHGr6k

func IKSolver(postures: [Posture], maxIt: Int) {
    for target in postures {
        if target.bone.ikLinks.count == 0 {
            continue;
        }
        
        let effector  = postures[target.bone.ikTargetBoneIndex]
        let targetPos = target.worldPos
        let ikLinks   = target.bone.ikLinks
        let iteration = maxIt >= 0 ? maxIt : Int(target.bone.ikLoopCount)

        for _ in 0 ..< iteration {
            
            for ikLink in ikLinks { 
                let link = postures[ikLink.boneIndex]
                let linkPos = link.worldPos
                let invLinkQ = link.worldRot.inverse()
                let effectorPos = effector.worldPos

                var effectorVec = effectorPos
                effectorVec = effectorVec.sub(linkPos)
                effectorVec = invLinkQ.rotate(effectorVec)
                effectorVec = effectorVec.normal()
                
                var targetVec = targetPos.sub(linkPos)
                targetVec = invLinkQ.rotate(targetVec)
                targetVec = targetVec.normal()
                
                var angle = targetVec.dot(effectorVec)
                if angle > 1.0 {
                    angle = 1.0
                } else if angle < -1.0 {
                    angle = -1.0
                }
                angle = acosf(angle)
                
                if angle > target.bone.ikAngularLimit {
                    angle = target.bone.ikAngularLimit
                }
                
                var axis = effectorVec.cross(targetVec)
                axis = axis.normal()
                let q = GLKQuaternionMakeWithAngleAndVector3Axis(angle, axis)
                link.q = link.q.mul(q)
                
                if ikLink.angularLimit {
                    var c = link.q.w
                    if c > 1.0 {
                        c = 1.0
                    }
                    
                    let c2 = sqrtf(1 - c * c)
                    if c >= 0 {
                        link.q = GLKQuaternionMake(c2, 0, 0, c)
                    } else if c < 0 {
                        // to prevent reverse joint when ankle touching buttocks
                        link.q = GLKQuaternionMake(-c2, 0, 0, c)
                    }
                }
 
                link.updateTransformMatrix(postures)
                effector.updateTransformMatrix(postures)
            }
        }
    }
}
