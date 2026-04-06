import Foundation
import GLKit
import simd

/// FK/IK 後の posture を Bullet world へ反映し、simulation 後の dynamic body だけを戻す。
/// MMD の制御ボーンは kinematic body として先に押し込み、揺れ物などの結果だけを引き戻す。
func PhysicsSolver(_ postures: [Posture], physicsSolving solver: PhysicsSolving) {
    for rigidBody in solver.rigidBodies {
        if rigidBody.boneIndex < 0 {
            continue
        }
        if rigidBody.type != 0 {
            continue
        }

        let posture = postures[rigidBody.boneIndex]
        solver.move(rigidBody.boneIndex,
                    rotation: posture.worldRot.simdQuaternion,
                    position: posture.worldPos.simdValue)
    }

    // 現行実装は MMD の 30fps 前提に合わせた刻みで world を進める。
    solver.step()

    for rigidBody in solver.rigidBodies {
        if rigidBody.boneIndex < 0 {
            continue
        }
        if rigidBody.type == 0 {
            continue
        }

        var rot = simd_quatf()
        var pos = simd_float3()
        solver.getTransform(rigidBody.boneIndex, rotation: &rot, position: &pos)

        let bone = postures[rigidBody.boneIndex].bone
        let m = GLKMatrix4.translation(pos.x, pos.y, pos.z).multiply(
            GLKMatrix4.rotation(GLKQuaternion(simd: rot)).multiply(
                GLKMatrix4.translation(-bone.pos.x, -bone.pos.y, -bone.pos.z)
            )
        )

        postures[rigidBody.boneIndex].wm = m
    }
}
