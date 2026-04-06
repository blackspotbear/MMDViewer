import Foundation
import GLKit
import simd

@objc
/// Swift 側の姿勢更新と Objective-C++ / Bullet 側 solver をつなぐ最小境界。
/// 呼び出し側は `PMXObject` に閉じ込め、物理エンジンの詳細をここより外へ漏らさない前提にする。
protocol PhysicsSolving {
    var rigidBodies: [RigidBody] { get }
    var constraints: [Constraint] { get }
    /// PMX 由来の剛体・constraint 定義から Bullet world を構築する初期化段。
    /// 生成後の solver は Swift 側から opaque な bridge として扱う。
    func build(_ rigidBodies: [RigidBody], constraints: [Constraint], bones: [Bone])
    /// Swift 側の姿勢はここで `simd` 値へ変換し、Bullet との往復型を `GLKit` から切り離す。
    func move(_ boneIndex: Int, rotation: simd_quatf, position: simd_float3)
    /// 物理結果を `simd` 値として受け取り、姿勢行列への反映だけを Swift 側で行う。
    func getTransform(_ boneIndex: Int,
                      rotation: UnsafeMutablePointer<simd_quatf>,
                      position: UnsafeMutablePointer<simd_float3>)
    func step()
}
