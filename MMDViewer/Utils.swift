import Foundation
import GLKit

func LoadPMD(_ resName: String) -> PMX! {
    let path = Bundle.main.path(forResource: resName, ofType: "pmx")
    if let path = path {
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        return PMX(data: data!)
    }
    return nil
}

func LoadVMD(_ resName: String) -> VMD! {
    let path = Bundle.main.path(forResource: resName, ofType: "vmd")
    if let path = path {
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        return VMD(data: data!)
    }
    return nil
}

func PMXVertex2NSData(_ vertices: [PMXVertex]) -> Data? {
    let data = NSMutableData(capacity: PMXVertex.packedSize * vertices.count)
    if let data = data {
        for var v in vertices {
            data.append(withUnsafePointer(to: &v.v) { UnsafeRawPointer($0) }, length: MemoryLayout<GLKVector3>.size)
            data.append(withUnsafePointer(to: &v.n) { UnsafeRawPointer($0) }, length: MemoryLayout<GLKVector3>.size)
            data.append(withUnsafePointer(to: &v.uv) { UnsafeRawPointer($0) }, length: MemoryLayout<UV>.size)
            data.append(withUnsafePointer(to: &v.boneWeights[0]) { UnsafeRawPointer($0) },
                             length: MemoryLayout<Float>.size * 4)
            data.append(withUnsafePointer(to: &v.boneIndices[0]) { UnsafeRawPointer($0) },
                             length: MemoryLayout<Int16>.size * 4)
        }
    }

    return data as Data?
}
