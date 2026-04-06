import Foundation
import GLKit

@objc
protocol PhysicsSolving {
    var rigidBodies: [RigidBody] { get }
    var constraints: [Constraint] { get }
    /// PMX 由来の剛体・constraint 定義から Bullet world を構築する初期化段。
    /// 生成後の solver は Swift 側から opaque な bridge として扱う。
    func build(_ rigidBodies: [RigidBody], constraints: [Constraint], bones: [Bone])
    /// Swift 側はまだ GLKit 型を使っているが、物理ブリッジはここを唯一の往復点に保つ。
    func move(_ boneIndex: Int, rot: GLKQuaternion, pos: GLKVector3)
    /// 物理結果をボーン姿勢へ戻す境界。今後 `simd` 化する場合もここを差し替え点にする。
    func getTransform(_ boneIndex: Int, rot: UnsafeMutablePointer<GLKQuaternion>, pos: UnsafeMutablePointer<GLKVector3>)
    func step()
}
