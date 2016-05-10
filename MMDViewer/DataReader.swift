import Foundation

class DataReader {
    var defaultEncoding = NSUTF16LittleEndianStringEncoding
    var data: NSData
    var pointer: UnsafePointer<Void>
    
    init(data: NSData) {
        self.data = data
        pointer = data.bytes
    }
    
    func read<T>() -> T {
        let t = UnsafePointer<T>(pointer)
        pointer = UnsafePointer<Void>(t.successor())
        return t.memory
    }
    
    func readIntN(n: Int) -> Int {
        if n == 1 {
            return Int(read() as UInt8)
        } else if n == 2 {
            return Int(read() as UInt16)
        } else if n == 4 {
            return Int(read() as UInt32)
        } else if (n == 8) {
            return read()
        }
        
        return 0;
    }
    
    func readString(encoding: UInt? = nil) -> String? {
        let length = Int(read() as UInt32)
        return readStringN(length, encoding: encoding)
    }
    
    func readStringN(nbytes: Int, encoding: UInt? = nil) -> String? {
        if nbytes == 0 {
            return ""
        }
        
        let r = NSString(bytes: pointer, length: nbytes, encoding: encoding ?? defaultEncoding) as String?
        pointer = pointer.advancedBy(nbytes)
        
        return r
    }
    
    func readCStringN(nbytes: Int, encoding: UInt? = nil) -> String? {
        if nbytes == 0 {
            return ""
        }
        
        var length = 0
        var p = pointer
        while true {
            let ch = UnsafePointer<UInt8>(p).memory
            if ch == 0 {
                break
            }
            p = p.successor()
            length += 1
        }
        
        let r = readStringN(length, encoding: encoding)
        pointer = pointer.advancedBy(nbytes - length)
        
        return r
    }
    
    func skip(nbytes: Int) {
        pointer = pointer.advancedBy(nbytes)
    }
}
