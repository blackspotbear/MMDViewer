import XCTest
import GLKit
import simd
@testable import MMDViewer

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
}
