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

    func begin() {
        events.add("renderer.begin")
    }

    func end() {
        events.add("renderer.end")
    }

    func reshape(_ bounds: CGRect) {}

    func setEndHandler(_ handler: @escaping (Renderer) -> Void) {}
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
