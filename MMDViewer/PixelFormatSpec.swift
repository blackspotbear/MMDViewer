import Foundation
import Metal

struct PixelFormatSpec {
    var colorAttachmentFormats = [MTLPixelFormat](repeating: .invalid, count: 4)
    var clearColors = [MTLClearColor](repeating: MTLClearColorMake(0, 0, 0, 0), count: 4)
    var depthPixelFormat = MTLPixelFormat.invalid
    var stencilPixelFormat = MTLPixelFormat.invalid
}
