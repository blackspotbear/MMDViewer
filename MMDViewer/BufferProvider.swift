import Foundation
import Metal

class BufferProvider {
    private let inflightBuffersCount: Int
    private var buffers: [MTLBuffer] = []
    private var availableBufferIndex = 0

    init(device: MTLDevice, inflightBuffersCount: Int, sizeOfUniformsBuffer: Int) {
        self.inflightBuffersCount = inflightBuffersCount
        for _ in 0..<inflightBuffersCount {
            let buffer = device.makeBuffer(length: sizeOfUniformsBuffer, options: [])!
            buffers.append(buffer)
        }
    }

    init(device: MTLDevice, inflightBuffersCount: Int, data: Data) {
        self.inflightBuffersCount = inflightBuffersCount
        for _ in 0..<inflightBuffersCount {
            let buffer = device.makeBuffer(bytes: (data as NSData).bytes, length: data.count, options: [])!
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
