import XCTest
import GLKit
import Metal
import simd
@testable import MMDViewer

/// バイナリ reader と quaternion helper のような、描画非依存の基礎ロジックを監視する。
final class MMDViewerTests: XCTestCase {

    func testReadAdvancesPointerAndReturnsTypedValue() {
        let data = data(bytes(of: UInt16(0x3412)))
        let sut = DataReader(data: data)

        let value: UInt16 = sut.read()

        XCTAssertEqual(value, 0x3412)
    }

    func testReadIntNSupportsCommonIntegerWidths() {
        let data = data(
            bytes(of: UInt8(0x12)),
            bytes(of: UInt16(0x3456)),
            bytes(of: UInt32(0x789ABCDE)),
            bytes(of: Int(0x0123456789ABCDEF))
        )
        let sut = DataReader(data: data)

        XCTAssertEqual(sut.readIntN(1), 0x12)
        XCTAssertEqual(sut.readIntN(2), 0x3456)
        XCTAssertEqual(sut.readIntN(4), 0x789ABCDE)
        XCTAssertEqual(sut.readIntN(8), 0x0123456789ABCDEF)
    }

    func testReadStringUsesLengthPrefixAndEncoding() {
        let text = "Miku"
        let textData = text.data(using: .utf16LittleEndian)!
        let length = UInt32(textData.count)
        let sut = DataReader(data: data(bytes(of: length), textData))

        XCTAssertEqual(sut.readString(), text)
    }

    func testReadStringNReturnsEmptyStringForZeroLength() {
        let sut = DataReader(data: Data())

        XCTAssertEqual(sut.readStringN(0), "")
    }

    func testReadCStringNSkipsPaddingBytes() {
        let stringBytes = Data([0x61, 0x62, 0x00, 0xFF, 0xEE])
        let trailingValue = data(bytes(of: UInt8(0x42)))
        let sut = DataReader(data: data(stringBytes, trailingValue))

        XCTAssertEqual(sut.readCStringN(5, encoding: String.Encoding.ascii.rawValue), "ab")
        let value: UInt8 = sut.read()
        XCTAssertEqual(value, 0x42)
    }

    func testSkipAdvancesReaderPosition() {
        let sut = DataReader(data: data(
            bytes(of: UInt8(0x10)),
            bytes(of: UInt8(0x20)),
            bytes(of: UInt8(0x30))
        ))

        sut.skip(2)
        let value: UInt8 = sut.read()

        XCTAssertEqual(value, 0x30)
    }

    func testQuaternionRoundTripsThroughSimdRepresentation() {
        let quaternion = GLKQuaternionNormalize(GLKQuaternionMake(0.1, -0.2, 0.3, 0.9))

        let roundTrip = GLKQuaternion(simd: quaternion.simdQuaternion)

        XCTAssertEqual(roundTrip.x, quaternion.x, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.y, quaternion.y, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.z, quaternion.z, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.w, quaternion.w, accuracy: 1e-6)
    }

    func testQuaternionMultiplyMatchesSimdComposition() {
        let left = GLKQuaternionNormalize(GLKQuaternionMakeWithAngleAndVector3Axis(.pi / 3, GLKVector3Make(0, 1, 0)))
        let right = GLKQuaternionNormalize(GLKQuaternionMakeWithAngleAndVector3Axis(.pi / 4, GLKVector3Make(1, 0, 0)))

        let result = left.mul(right)
        let expected = GLKQuaternion(simd: simd_mul(left.simdQuaternion, right.simdQuaternion))

        XCTAssertEqual(result.x, expected.x, accuracy: 1e-6)
        XCTAssertEqual(result.y, expected.y, accuracy: 1e-6)
        XCTAssertEqual(result.z, expected.z, accuracy: 1e-6)
        XCTAssertEqual(result.w, expected.w, accuracy: 1e-6)
    }

    func testQuaternionRotateVectorMatchesSimdAct() {
        let quaternion = GLKQuaternionNormalize(GLKQuaternionMakeWithAngleAndVector3Axis(.pi / 2, GLKVector3Make(0, 0, 1)))
        let vector = GLKVector3Make(1, 0, 0)

        let result = quaternion.rotate(vector)
        let expected = GLKVector3(simd: simd_act(quaternion.simdQuaternion, vector.simdValue))

        XCTAssertEqual(result.x, expected.x, accuracy: 1e-6)
        XCTAssertEqual(result.y, expected.y, accuracy: 1e-6)
        XCTAssertEqual(result.z, expected.z, accuracy: 1e-6)
    }

    private func data(_ parts: Data...) -> Data {
        parts.reduce(into: Data()) { partialResult, part in
            partialResult.append(part)
        }
    }

    private func bytes<T>(of value: T) -> Data {
        var value = value
        return withUnsafeBytes(of: &value) { Data($0) }
    }
    
    private func fixtureData(at relativePath: String) -> Data? {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }
}

/// GLKit 互換レイヤーと traversal 規約をまとめて監視する。
/// `simd` 置換の途中でも legacy GLKit と同じ振る舞いを維持できているかをここで固定する。
final class MatrixBridgingTests: XCTestCase {

    func testRoundTripsThroughSimdRepresentation() {
        // 行列表現を `GLKMatrix4` <-> `simd_float4x4` で往復しても、
        // 要素の並び順が崩れないことを固定する。
        let matrix = GLKMatrix4Make(1, 2, 3, 4,
                                    5, 6, 7, 8,
                                    9, 10, 11, 12,
                                    13, 14, 15, 16)

        let roundTrip = GLKMatrix4(simd: matrix.simdMatrix)

        XCTAssertEqual(roundTrip.m00, matrix.m00, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m01, matrix.m01, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m02, matrix.m02, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m03, matrix.m03, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m10, matrix.m10, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m11, matrix.m11, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m12, matrix.m12, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m13, matrix.m13, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m20, matrix.m20, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m21, matrix.m21, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m22, matrix.m22, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m23, matrix.m23, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m30, matrix.m30, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m31, matrix.m31, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m32, matrix.m32, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.m33, matrix.m33, accuracy: 1e-6)
    }

    func testMatrixHelpersMatchLegacyGLKOperations() {
        // instance helper は call site を読みやすくするための薄い互換層なので、
        // 既存の GLKit 実装と完全一致することを保つ。
        let base = GLKMatrix4Multiply(
            GLKMatrix4MakeTranslation(1, 2, 3),
            GLKMatrix4MakeRotation(.pi / 7, 0, 1, 0)
        )
        let other = GLKMatrix4MakeTranslation(2, -3, 4)

        let scaled = base.scale(1.5, y: 2.0, z: 2.5)
        assertEqualMatrix(scaled, GLKMatrix4Scale(base, 1.5, 2.0, 2.5))

        let translated = base.translate(3, y: -4, z: 5)
        assertEqualMatrix(translated, GLKMatrix4Translate(base, 3, -4, 5))

        let rotated = base.rotateAroundX(.pi / 8, y: .pi / 6, z: .pi / 4)
        let legacyRotated = GLKMatrix4Rotate(
            GLKMatrix4Rotate(
                GLKMatrix4Rotate(base, .pi / 8, 1, 0, 0),
                .pi / 6, 0, 1, 0
            ),
            .pi / 4, 0, 0, 1
        )
        assertEqualMatrix(rotated, legacyRotated)

        assertEqualMatrix(base.multiply(other), GLKMatrix4Multiply(base, other))
        assertEqualMatrix(base.multiplyLeft(other), GLKMatrix4Multiply(other, base))
        assertEqualMatrix(base.transpose(), GLKMatrix4Transpose(base))
    }

    func testMatrixFactoriesMatchLegacyGLKConstructors() {
        // ここは GLKit の factory を `simd` 実装で置き換える時の安全網。
        let translation = GLKMatrix4.translation(1, 2, 3)
        assertEqualMatrix(translation, GLKMatrix4MakeTranslation(1, 2, 3))

        let scale = GLKMatrix4.scale(4, 5, 6)
        assertEqualMatrix(scale, GLKMatrix4MakeScale(4, 5, 6))

        let quaternion = GLKQuaternionNormalize(
            GLKQuaternionMakeWithAngleAndVector3Axis(.pi / 3, GLKVector3Make(0, 1, 0))
        )
        let rotation = GLKMatrix4.rotation(quaternion)
        assertEqualMatrix(rotation, GLKMatrix4MakeWithQuaternion(quaternion))

        let lookAt = GLKMatrix4.lookAt(
            eye: GLKVector3Make(0, 10, 20),
            center: GLKVector3Make(0, 10, 0),
            up: GLKVector3Make(0, 1, 0)
        )
        assertEqualMatrix(lookAt, GLKMatrix4MakeLookAt(0, 10, 20, 0, 10, 0, 0, 1, 0))

        let perspective = GLKMatrix4.perspective(
            fovyRadians: GLKMathDegreesToRadians(85.0),
            aspect: 1.5,
            near: 0.01,
            far: 100.0
        )
        assertEqualMatrix(
            perspective,
            GLKMatrix4MakePerspective(GLKMathDegreesToRadians(85.0), 1.5, 0.01, 100.0)
        )

        let ortho = GLKMatrix4.orthographicOffCenter(
            left: -12, right: 12,
            bottom: -12, top: 12,
            near: 1, far: 20
        )
        let expectedOrtho = GLKMatrix4Make(
            2.0 / 24.0, 0, 0, 0,
            0, 2.0 / 24.0, 0, 0,
            0, 0, -1.0 / 19.0, 0,
            0, 0, -1.0 / 19.0, 1
        )
        assertEqualMatrix(ortho, expectedOrtho)
    }

    func testMultiplyVector4MatchesLegacyGLKOperation() {
        // matrix-vector 適用は row-vector / column-vector の規約差が出やすいので、
        // ここで GLKit と同じ向きになっていることを明示的に縛る。
        let matrix = GLKMatrix4MakeRotation(.pi / 3, 0, 1, 0)
        let vector = GLKVector4Make(1, 2, 3, 1)

        let result = matrix.multiplyVector4(vector)
        let expected = GLKMatrix4MultiplyVector4(matrix, vector)

        XCTAssertEqual(result.x, expected.x, accuracy: 1e-6)
        XCTAssertEqual(result.y, expected.y, accuracy: 1e-6)
        XCTAssertEqual(result.z, expected.z, accuracy: 1e-6)
        XCTAssertEqual(result.w, expected.w, accuracy: 1e-6)
    }

    func testVectorHelpersMatchLegacyGLKOperations() {
        // ベクトル helper は実装だけ `simd` 化したので、GLKit と同値であることを固定する。
        let left = GLKVector3Make(1, 2, 3)
        let right = GLKVector3Make(-4, 5, -6)

        assertEqualVector3(left.add(right), GLKVector3Add(left, right))
        assertEqualVector3(left.sub(right), GLKVector3Subtract(left, right))
        XCTAssertEqual(left.len(), GLKVector3Length(left), accuracy: 1e-6)
        assertEqualVector3(left.mul(2.5), GLKVector3MultiplyScalar(left, 2.5))
        assertEqualVector3(left.normal(), GLKVector3Normalize(left))
        assertEqualVector3(left.outer(right), GLKVector3CrossProduct(left, right))
        XCTAssertEqual(left.inner(right), GLKVector3DotProduct(left, right), accuracy: 1e-6)
        XCTAssertEqual(left.dot(right), GLKVector3DotProduct(left, right), accuracy: 1e-6)
        assertEqualVector3(left.cross(right), GLKVector3CrossProduct(left, right))

        let zero = GLKVector3Make(0, 0, 0)
        assertEqualVector3(zero.normal(), zero)
    }

    func testVector4HelpersMatchLegacyGLKOperations() {
        // fragment / light 系で使う `GLKVector4` helper も同じ方針で監視する。
        let left = GLKVector4Make(1, 2, 3, 4)
        let right = GLKVector4Make(-4, 5, -6, 7)

        let result = left.sub(right)
        let expected = GLKVector4Subtract(left, right)

        XCTAssertEqual(result.x, expected.x, accuracy: 1e-6)
        XCTAssertEqual(result.y, expected.y, accuracy: 1e-6)
        XCTAssertEqual(result.z, expected.z, accuracy: 1e-6)
        XCTAssertEqual(result.w, expected.w, accuracy: 1e-6)
    }

    func testVector2RoundTripsThroughSimdRepresentation() {
        let vector = GLKVector2Make(12.5, -3.25)

        let roundTrip = GLKVector2(simd: vector.simdValue)

        XCTAssertEqual(roundTrip.x, vector.x, accuracy: 1e-6)
        XCTAssertEqual(roundTrip.y, vector.y, accuracy: 1e-6)
    }

    func testTraverserUpdateTraversesParentBeforeChildren() {
        // 姿勢やカメラ更新は親から子へ伝播する前提なので、visit 順序を明示的に固定する。
        let renderer = RendererSpy()
        let traverser = Traverser(renderer: renderer)
        let root = Node()
        let child = Node()
        let grandchild = Node()

        root.updater = RecordingUpdater(name: "root", events: renderer.events)
        child.updater = RecordingUpdater(name: "child", events: renderer.events)
        grandchild.updater = RecordingUpdater(name: "grandchild", events: renderer.events)
        child.children = [grandchild]
        root.children = [child]

        traverser.update(1.0 / 60.0, node: root)

        XCTAssertEqual(renderer.events.values, [
            "update:root",
            "update:child",
            "update:grandchild",
        ])
    }

    func testTraverserDrawBalancesPassesAndModelMatrixStack() {
        // draw 順序と push / pop の対応が崩れると、compile は通っても見た目だけ壊れやすい。
        let renderer = RendererSpy()
        let traverser = Traverser(renderer: renderer)
        let root = Node()
        let child = Node()

        root.pass = RecordingPass(name: "root", events: renderer.events)
        root.drawer = RecordingDrawer(name: "root", events: renderer.events)
        child.modelMatrix = GLKMatrix4MakeTranslation(1, 2, 3)
        child.pass = RecordingPass(name: "child", events: renderer.events)
        child.drawer = RecordingDrawer(name: "child", events: renderer.events)
        root.children = [child]

        traverser.draw(root)

        XCTAssertEqual(renderer.events.values, [
            "renderer.begin",
            "pass.begin:root",
            "draw:root",
            "pass.begin:child",
            "pushModelMatrix",
            "draw:child",
            "popModelMatrix",
            "pass.end:child",
            "pass.end:root",
            "renderer.end",
        ])
        XCTAssertEqual(renderer.modelMatrixStackDepth, 1)
    }

    func testBasicRendererModelMatrixTracksTopOfStack() {
        // renderer の modelMatrix は stack 先頭の糖衣構文として使っているので、
        // setter / getter が push / pop と矛盾しないことを固定する。
        let renderer = BasicRenderer()
        let pushed = GLKMatrix4MakeTranslation(1, 2, 3)
        let replacement = GLKMatrix4MakeTranslation(4, 5, 6)

        renderer.pushModelMatrix(pushed)
        assertEqualMatrix(renderer.modelMatrix, pushed)

        renderer.modelMatrix = replacement
        assertEqualMatrix(renderer.modelMatrix, replacement)
        assertEqualMatrix(renderer.popModelMatrix(), replacement)
        assertEqualMatrix(renderer.modelMatrix, GLKMatrix4Identity)
    }

    func testCurveValueReturnsExactKeyFrameValues() {
        // 補間の手前で frame がぴったり key に一致する場合は、
        // 元データをそのまま返すことが animator の基準になる。
        let key = makeKeyFrame(
            frameNum: 12,
            position: GLKVector3Make(1, 2, 3),
            rotation: GLKQuaternionNormalize(GLKQuaternionMake(0.1, 0.2, 0.3, 0.9))
        )
        let tie = CurveTie()
        tie.keys = [key]

        let (rotation, position) = GetCurveValue(tie, frameNum: 12)
        guard let position, let rotation else {
            XCTFail("Expected exact keyframe values")
            return
        }

        XCTAssertEqual(position.x, 1, accuracy: 1e-6)
        XCTAssertEqual(position.y, 2, accuracy: 1e-6)
        XCTAssertEqual(position.z, 3, accuracy: 1e-6)
        XCTAssertEqual(rotation.x, key.segments[BoneAttr.QX].value, accuracy: 1e-6)
        XCTAssertEqual(rotation.y, key.segments[BoneAttr.QY].value, accuracy: 1e-6)
        XCTAssertEqual(rotation.z, key.segments[BoneAttr.QZ].value, accuracy: 1e-6)
        XCTAssertEqual(rotation.w, key.segments[BoneAttr.QW].value, accuracy: 1e-6)
    }

    func testCurveValueInterpolatesLinearlyBetweenKeyFrames() {
        // 補間ハンドルを直線に寄せたときの中間値を固定して、
        // VMD カーブ実装を差し替えても基本挙動がずれないようにする。
        let start = makeKeyFrame(
            frameNum: 0,
            position: GLKVector3Make(1, 2, 3),
            rotation: GLKQuaternionIdentity
        )
        let end = makeKeyFrame(
            frameNum: 10,
            position: GLKVector3Make(11, 22, 33),
            rotation: GLKQuaternionMakeWithAngleAndVector3Axis(.pi, GLKVector3Make(0, 1, 0))
        )
        let tie = CurveTie()
        tie.keys = [start, end]

        let (rotation, position) = GetCurveValue(tie, frameNum: 5)
        guard let position, let rotation else {
            XCTFail("Expected interpolated keyframe values")
            return
        }

        XCTAssertEqual(position.x, 6, accuracy: 1e-4)
        XCTAssertEqual(position.y, 12, accuracy: 1e-4)
        XCTAssertEqual(position.z, 18, accuracy: 1e-4)

        let rotated = rotation.rotate(GLKVector3Make(0, 0, 1))
        XCTAssertEqual(rotated.x, 1, accuracy: 1e-4)
        XCTAssertEqual(rotated.y, 0, accuracy: 1e-4)
        XCTAssertEqual(rotated.z, 0, accuracy: 1e-4)
    }

    func testLoadModelAndMotionFixtures() {
        guard let pmxData = fixtureData(at: "data/mmd/Alicia_solid.pmx") else {
            XCTFail("Missing PMX fixture")
            return
        }
        let pmx = PMX(data: pmxData)

        XCTAssertEqual(pmx.meta.format, "PMX ")
        XCTAssertGreaterThanOrEqual(pmx.meta.version, 2.0)
        XCTAssertFalse(pmx.meta.modelName.isEmpty)
        XCTAssertFalse(pmx.vertices.isEmpty)
        XCTAssertFalse(pmx.indices.isEmpty)
        XCTAssertFalse(pmx.materials.isEmpty)
        XCTAssertFalse(pmx.bones.isEmpty)
        XCTAssertFalse(pmx.texturePaths.isEmpty)

        guard let vmdData = fixtureData(at: "data/vmd/2分ループステップ1.vmd") else {
            XCTFail("Missing VMD fixture")
            return
        }
        let vmd = VMD(data: vmdData)

        XCTAssertFalse(vmd.meta.content.isEmpty)
        XCTAssertGreaterThan(vmd.meta.totalFrameCount, 0)
        XCTAssertGreaterThan(vmd.meta.frameCount, 0)
        XCTAssertFalse(vmd.curveTies.isEmpty)
    }

    func testPhysicsSolverPushesKinematicBodiesAndPullsDynamicBodies() {
        // 物理 bridge は kinematic body だけを Bullet へ押し込み、
        // simulation 後は dynamic body だけを posture へ戻す前提なので、その往復を固定する。
        let kinematicBone = makeBone(name: "kinematic", position: GLKVector3Make(1, 2, 3))
        let dynamicBone = makeBone(name: "dynamic", position: GLKVector3Make(4, 5, 6))
        let postures = [Posture(bone: kinematicBone), Posture(bone: dynamicBone)]

        postures[0].wm = GLKMatrix4.translation(10, 20, 30)
            .multiply(GLKMatrix4.rotation(GLKQuaternionNormalize(
                GLKQuaternionMakeWithAngleAndVector3Axis(.pi / 2, GLKVector3Make(0, 1, 0))
            )))
        postures[1].wm = GLKMatrix4Identity

        let rigidBodies = [
            makeRigidBody(name: "kinematic", boneIndex: 0, type: 0),
            makeRigidBody(name: "dynamic", boneIndex: 1, type: 1),
        ]
        let expectedDynamicRotation = simd_quatf(angle: .pi / 3, axis: simd_normalize(simd_float3(0, 1, 1)))
        let expectedDynamicPosition = simd_float3(7, 8, 9)
        let solver = PhysicsSolvingSpy(
            rigidBodies: rigidBodies,
            returnedRotation: expectedDynamicRotation,
            returnedPosition: expectedDynamicPosition
        )

        PhysicsSolver(postures, physicsSolving: solver)

        XCTAssertEqual(solver.moves.count, 1)
        XCTAssertEqual(solver.moves[0].boneIndex, 0)
        XCTAssertEqual(solver.moves[0].position.x, postures[0].worldPos.x, accuracy: 1e-6)
        XCTAssertEqual(solver.moves[0].position.y, postures[0].worldPos.y, accuracy: 1e-6)
        XCTAssertEqual(solver.moves[0].position.z, postures[0].worldPos.z, accuracy: 1e-6)
        XCTAssertEqual(solver.moves[0].rotation.vector.x, postures[0].worldRot.simdQuaternion.vector.x, accuracy: 1e-6)
        XCTAssertEqual(solver.moves[0].rotation.vector.y, postures[0].worldRot.simdQuaternion.vector.y, accuracy: 1e-6)
        XCTAssertEqual(solver.moves[0].rotation.vector.z, postures[0].worldRot.simdQuaternion.vector.z, accuracy: 1e-6)
        XCTAssertEqual(solver.moves[0].rotation.vector.w, postures[0].worldRot.simdQuaternion.vector.w, accuracy: 1e-6)
        XCTAssertEqual(solver.stepCallCount, 1)
        XCTAssertEqual(solver.requestedBoneIndices, [1])

        let expectedMatrix = GLKMatrix4.translation(expectedDynamicPosition.x, expectedDynamicPosition.y, expectedDynamicPosition.z).multiply(
            GLKMatrix4.rotation(GLKQuaternion(simd: expectedDynamicRotation)).multiply(
                GLKMatrix4.translation(-dynamicBone.pos.x, -dynamicBone.pos.y, -dynamicBone.pos.z)
            )
        )
        assertEqualMatrix(postures[1].wm, expectedMatrix)
    }

    func testPMXUpdaterAdvancesFrameAndAppliesAngularDecayWhenPlaying() {
        // updater は input 由来の角速度を減衰しつつ、再生中だけ frame を進める。
        let updater = makeFixturePMXUpdater()
        let renderer = RendererSpy()
        let initialFrame = updater.pmxObj.counter.currentFrame()
        updater.angularVelocity = CGPoint(x: 2, y: -3)
        updater.playing = true

        updater.update(1.0, renderer: renderer, node: Node())

        XCTAssertEqual(updater.pmxObj.counter.currentFrame(), initialFrame + 1)
        XCTAssertEqual(updater.pmxObj.rotationX, -3, accuracy: 1e-5)
        XCTAssertEqual(updater.pmxObj.rotationY, 2, accuracy: 1e-5)
        XCTAssertEqual(updater.angularVelocity.x, 1.9, accuracy: 1e-5)
        XCTAssertEqual(updater.angularVelocity.y, -2.85, accuracy: 1e-5)
        XCTAssertNotNil(updater.pmxObj.currentVertexBuffer)
    }

    func testPMXUpdaterKeepsFrameWhenPaused() {
        // 背景遷移や UI pause 中は、姿勢更新は走っても frame counter は進めない。
        let updater = makeFixturePMXUpdater()
        let renderer = RendererSpy()
        let initialFrame = updater.pmxObj.counter.currentFrame()
        updater.angularVelocity = CGPoint(x: 1, y: 1)
        updater.playing = false

        updater.update(1.0 / 60.0, renderer: renderer, node: Node())

        XCTAssertEqual(updater.pmxObj.counter.currentFrame(), initialFrame)
        XCTAssertEqual(updater.pmxObj.rotationX, Float(1.0 / 60.0), accuracy: 1e-5)
        XCTAssertEqual(updater.pmxObj.rotationY, Float(1.0 / 60.0), accuracy: 1e-5)
        XCTAssertEqual(updater.angularVelocity.x, 0.95, accuracy: 1e-5)
        XCTAssertEqual(updater.angularVelocity.y, 0.95, accuracy: 1e-5)
    }

    func testCameraUpdaterBuildsViewMatrixFromInverseRotationAndTranslation() {
        // camera updater は gesture 由来の回転と位置から view 行列を組み立てる責務だけを持つ。
        // ここが崩れると描画自体は成功しても視点だけが破綻するので、純ロジックとして固定する。
        let rotation = GLKQuaternionNormalize(
            GLKQuaternionMakeWithAngleAndVector3Axis(.pi / 3, GLKVector3Make(0, 1, 0))
        )
        let position = GLKVector3Make(3, 4, 5)
        let updater = CameraUpdater(rot: rotation, pos: position)
        let renderer = RendererSpy()

        updater.update(1.0 / 60.0, renderer: renderer, node: Node())

        let expected = GLKMatrix4.rotation(rotation.inverse()).multiply(
            GLKMatrix4.translation(-position.x, -position.y, -position.z)
        )
        assertEqualMatrix(renderer.viewMatrix, expected)
        assertEqualMatrix(updater.viewMatrix, expected)
    }

    private func fixtureData(at relativePath: String) -> Data? {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = projectRoot.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }

    private func makeKeyFrame(frameNum: Int, position: GLKVector3, rotation: GLKQuaternion) -> KeyFrame {
        var key = KeyFrame(frameNum)
        key.segments[BoneAttr.TX].value = position.x
        key.segments[BoneAttr.TY].value = position.y
        key.segments[BoneAttr.TZ].value = position.z
        key.segments[BoneAttr.QX].value = rotation.x
        key.segments[BoneAttr.QY].value = rotation.y
        key.segments[BoneAttr.QZ].value = rotation.z
        key.segments[BoneAttr.QW].value = rotation.w

        for attr in 0..<BoneAttr.count {
            key.segments[attr].controlPoint[0] = GLKVector2Make(0, 0)
            key.segments[attr].controlPoint[1] = GLKVector2Make(127, 127)
        }

        return key
    }

    private func makeBone(name: String, position: GLKVector3) -> Bone {
        Bone(
            name: name,
            nameE: name,
            pos: position,
            parentBoneIndex: Int.max,
            deformLayer: 0,
            bitFlag: [],
            childOffset: GLKVector3Make(0, 0, 0),
            childBoneIndex: -1,
            affectingParentBoneIndex: -1,
            affectingRate: 0,
            fixAxis: GLKVector3Make(0, 0, 0),
            xAxis: GLKVector3Make(1, 0, 0),
            zAxis: GLKVector3Make(0, 0, 1),
            key: 0,
            ikTargetBoneIndex: -1,
            ikLoopCount: 0,
            ikAngularLimit: 0,
            ikLinks: []
        )
    }

    private func makeRigidBody(name: String, boneIndex: Int, type: UInt8) -> RigidBody {
        RigidBody(
            name: name,
            nameE: name,
            boneIndex: boneIndex,
            groupID: 0,
            groupFlag: 0,
            shapeType: 0,
            size: GLKVector3Make(1, 1, 1),
            pos: GLKVector3Make(0, 0, 0),
            rot: GLKVector3Make(0, 0, 0),
            mass: 1,
            linearDamping: 0,
            angularDamping: 0,
            restitution: 0,
            friction: 0,
            type: type
        )
    }

    private func makeFixturePMXUpdater(file: StaticString = #filePath, line: UInt = #line) -> PMXUpdater {
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Missing Metal device", file: file, line: line)
            fatalError("Missing Metal device")
        }
        guard let pmxData = fixtureData(at: "data/mmd/Alicia_solid.pmx") else {
            XCTFail("Missing PMX fixture", file: file, line: line)
            fatalError("Missing PMX fixture")
        }
        guard let vmdData = fixtureData(at: "data/vmd/2分ループステップ1.vmd") else {
            XCTFail("Missing VMD fixture", file: file, line: line)
            fatalError("Missing VMD fixture")
        }

        let pmx = PMX(data: pmxData)
        let vmd = VMD(data: vmdData)
        return PMXUpdater(pmxObj: PMXObject(device: device, pmx: pmx, vmd: vmd))
    }

    private func assertEqualMatrix(_ lhs: GLKMatrix4, _ rhs: GLKMatrix4, accuracy: Float = 1e-5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.m00, rhs.m00, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m01, rhs.m01, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m02, rhs.m02, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m03, rhs.m03, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m10, rhs.m10, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m11, rhs.m11, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m12, rhs.m12, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m13, rhs.m13, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m20, rhs.m20, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m21, rhs.m21, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m22, rhs.m22, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m23, rhs.m23, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m30, rhs.m30, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m31, rhs.m31, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m32, rhs.m32, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.m33, rhs.m33, accuracy: accuracy, file: file, line: line)
    }

    private func assertEqualVector3(_ lhs: GLKVector3, _ rhs: GLKVector3, accuracy: Float = 1e-6, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.z, rhs.z, accuracy: accuracy, file: file, line: line)
    }
}

/// renderer の副作用だけを観測するための最小 spy。
/// 実 GPU 資源を持たず、traversal と matrix stack の契約だけを検証する。
private final class RendererSpy: Renderer {
    let events = EventLog()

    private var modelMatrixStack = [GLKMatrix4Identity]

    var modelMatrixStackDepth: Int { modelMatrixStack.count }

    func pushModelMatrix(_ mtrx: GLKMatrix4) {
        events.add("pushModelMatrix")
        modelMatrixStack.append(mtrx)
    }

    @discardableResult
    func popModelMatrix() -> GLKMatrix4 {
        events.add("popModelMatrix")
        return modelMatrixStack.popLast() ?? GLKMatrix4Identity
    }

    var modelMatrix: GLKMatrix4 {
        get { modelMatrixStack.last ?? GLKMatrix4Identity }
        set { modelMatrixStack[modelMatrixStack.index(before: modelMatrixStack.endIndex)] = newValue }
    }

    var viewMatrix = GLKMatrix4Identity
    var projectionMatrix = GLKMatrix4Identity
    var textureResources = [String: MTLTexture]()
    var commandBuffer: MTLCommandBuffer?
    var renderCommandEncoderStack = [MTLRenderCommandEncoder]()
    var renderCommandEncoder: MTLRenderCommandEncoder? { renderCommandEncoderStack.last }

    func pushRenderCommandEncoder(_ encoder: MTLRenderCommandEncoder) {
        events.add("pushRenderCommandEncoder")
        renderCommandEncoderStack.append(encoder)
    }

    @discardableResult
    func popRenderCommandEncoder() -> MTLRenderCommandEncoder? {
        events.add("popRenderCommandEncoder")
        return renderCommandEncoderStack.popLast()
    }

    func begin() {
        events.add("renderer.begin")
    }

    func end() {
        events.add("renderer.end")
    }

    func reshape(_ bounds: CGRect) {}

    func setEndHandler(_ handler: @escaping (Renderer) -> Void) {}
}

private final class PhysicsSolvingSpy: PhysicsSolving {
    struct MoveCall {
        let boneIndex: Int
        let rotation: simd_quatf
        let position: simd_float3
    }

    let rigidBodies: [RigidBody]
    let constraints: [Constraint] = []
    var moves: [MoveCall] = []
    var stepCallCount = 0
    var requestedBoneIndices: [Int] = []

    private let returnedRotation: simd_quatf
    private let returnedPosition: simd_float3

    init(rigidBodies: [RigidBody], returnedRotation: simd_quatf, returnedPosition: simd_float3) {
        self.rigidBodies = rigidBodies
        self.returnedRotation = returnedRotation
        self.returnedPosition = returnedPosition
    }

    func build(_ rigidBodies: [RigidBody], constraints: [Constraint], bones: [Bone]) {}

    func move(_ boneIndex: Int, rotation: simd_quatf, position: simd_float3) {
        moves.append(MoveCall(boneIndex: boneIndex, rotation: rotation, position: position))
    }

    func getTransform(_ boneIndex: Int,
                      rotation: UnsafeMutablePointer<simd_quatf>,
                      position: UnsafeMutablePointer<simd_float3>) {
        requestedBoneIndices.append(boneIndex)
        rotation.pointee = returnedRotation
        position.pointee = returnedPosition
    }

    func step() {
        stepCallCount += 1
    }
}

private final class EventLog {
    private(set) var values: [String] = []

    func add(_ value: String) {
        values.append(value)
    }
}

private final class RecordingUpdater: Updater {
    private let name: String
    private let events: EventLog

    init(name: String, events: EventLog) {
        self.name = name
        self.events = events
    }

    func update(_ dt: CFTimeInterval, renderer: Renderer, node: Node) {
        events.add("update:\(name)")
    }
}

private final class RecordingDrawer: Drawer {
    private let name: String
    private let events: EventLog

    init(name: String, events: EventLog) {
        self.name = name
        self.events = events
    }

    func draw(_ renderer: Renderer) {
        events.add("draw:\(name)")
    }
}

private final class RecordingPass: RenderPass {
    private let name: String
    private let events: EventLog

    init(name: String, events: EventLog) {
        self.name = name
        self.events = events
    }

    func begin(_ renderer: Renderer) {
        events.add("pass.begin:\(name)")
    }

    func end(_ renderer: Renderer) {
        events.add("pass.end:\(name)")
    }
}
