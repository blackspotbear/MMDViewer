import Foundation
import Metal

class BufferProvider {
    private let inflightBuffersCount: Int
    private var buffers: [MTLBuffer] = []
    private var availableBufferIndex = 0
    
    init(device: MTLDevice, inflightBuffersCount: Int, sizeOfUniformsBuffer: Int) {
        self.inflightBuffersCount = inflightBuffersCount
        for _ in 0..<inflightBuffersCount {
            let buffer = device.newBufferWithLength(sizeOfUniformsBuffer, options: [])
            buffers.append(buffer)
        }
    }
    
    init(device: MTLDevice, inflightBuffersCount: Int, data: NSData) {
        self.inflightBuffersCount = inflightBuffersCount
        for _ in 0..<inflightBuffersCount {
            let buffer = device.newBufferWithBytes(data.bytes, length: data.length, options: [])
            buffers.append(buffer)
        }
    }
    
    func nextBuffer() -> MTLBuffer {
        let buffer = buffers[availableBufferIndex]
        
        availableBufferIndex += 1
        if availableBufferIndex == inflightBuffersCount {
            availableBufferIndex = 0
        }
        
        return buffer
    }
}
