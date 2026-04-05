import XCTest
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

    private func data(_ parts: Data...) -> Data {
        parts.reduce(into: Data()) { partialResult, part in
            partialResult.append(part)
        }
    }

    private func bytes<T>(of value: T) -> Data {
        var value = value
        return withUnsafeBytes(of: &value) { Data($0) }
    }
}
