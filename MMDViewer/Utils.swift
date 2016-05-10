import Foundation
import GLKit

func LoadPMD(resName: String) -> PMX! {
    let path = NSBundle.mainBundle().pathForResource(resName, ofType: "pmx")
    if let path = path {
        let data = NSData(contentsOfFile: path)
        return PMX(data: data!)
    }
    return nil
}

func LoadVMD(resName: String) -> VMD! {
    let path = NSBundle.mainBundle().pathForResource(resName, ofType: "vmd")
    if let path = path {
        let data = NSData(contentsOfFile: path)
        return VMD(data: data!)
    }
    return nil
}

func PMXVertex2NSData(vertices: [PMXVertex]) -> NSData? {
    let data = NSMutableData(capacity: PMXVertex.packedSize * vertices.count)
    if let data = data {
        for var v in vertices {
            data.appendBytes(withUnsafePointer(&v.v) { UnsafePointer($0) }, length: sizeof(GLKVector3))
            data.appendBytes(withUnsafePointer(&v.n) { UnsafePointer($0) }, length: sizeof(GLKVector3))
            data.appendBytes(withUnsafePointer(&v.uv) { UnsafePointer($0) }, length: sizeof(UV))
            data.appendBytes(withUnsafePointer(&v.boneWeights[0]) { UnsafePointer($0) },
                             length: sizeof(Float) * 4)
            data.appendBytes(withUnsafePointer(&v.boneIndices[0]) { UnsafePointer($0) },
                             length: sizeof(Int16) * 4)
        }
    }
    
    return data
}
