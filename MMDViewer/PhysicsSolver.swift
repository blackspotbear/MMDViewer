import Foundation
import GLKit

func PhysicsSolver(_ postures: [Posture], physicsSolving solver: PhysicsSolving) {
    for rigidBody in solver.rigidBodies {
        if rigidBody.boneIndex < 0 {
            continue
        }
        if rigidBody.type != 0 {
            continue
        }

        let posture = postures[rigidBody.boneIndex]
        solver.move(rigidBody.boneIndex, rot:posture.worldRot, pos:posture.worldPos)
    }

    solver.step()

    for rigidBody in solver.rigidBodies {
        if rigidBody.boneIndex < 0 {
            continue
        }
        if rigidBody.type == 0 {
            continue
        }

        var rot = GLKQuaternionMake(0, 0, 0, 0)
        var pos = GLKVector3Make(0, 0, 0)
        solver.getTransform(rigidBody.boneIndex, rot:&rot, pos:&pos)

        let bone = postures[rigidBody.boneIndex].bone
        let m = GLKMatrix4.translation(pos.x, pos.y, pos.z).multiply(
            GLKMatrix4.rotation(rot).multiply(
                GLKMatrix4.translation(-bone.pos.x, -bone.pos.y, -bone.pos.z)
            )
        )

        postures[rigidBody.boneIndex].wm = m
    }
}
