import Foundation

class DataReader {
    var defaultEncoding = String.Encoding.utf16LittleEndian
    var data: Data
    var pointer: UnsafeRawPointer

    init(data: Data) {
        self.data = data
        pointer = (data as NSData).bytes
    }

    func read<T>() -> T {
        let t = pointer.assumingMemoryBound(to: T.self)
        pointer = UnsafeRawPointer(t.successor())
        return t.pointee
    }

    func readIntN(_ n: Int) -> Int {
        if n == 1 {
            return Int(read() as UInt8)
        } else if n == 2 {
            return Int(read() as UInt16)
        } else if n == 4 {
            return Int(read() as UInt32)
        } else if n == 8 {
            return read()
        }

        return 0
    }

    func readString(_ encoding: UInt? = nil) -> String? {
        let length = Int(read() as UInt32)
        return readStringN(length, encoding: encoding)
    }

    func readStringN(_ nbytes: Int, encoding: UInt? = nil) -> String? {
        if nbytes == 0 {
            return ""
        }

        let r = NSString(bytes: pointer, length: nbytes, encoding: encoding ?? defaultEncoding.rawValue) as String?
        pointer = pointer.advanced(by: nbytes)

        return r
    }

    func readCStringN(_ nbytes: Int, encoding: UInt? = nil) -> String? {
        if nbytes == 0 {
            return ""
        }

        var length = 0
        var p = pointer
        while true {
            let ch = p.assumingMemoryBound(to: UInt8.self).pointee
            if ch == 0 {
                break
            }
            p = p.advanced(by: 1)
            length += 1
        }

        let r = readStringN(length, encoding: encoding)
        pointer = pointer.advanced(by: nbytes - length)

        return r
    }

    func skip(_ nbytes: Int) {
        pointer = pointer.advanced(by: nbytes)
    }
}
