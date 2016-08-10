import UIKit
import Metal
import CoreGraphics

// see http://www.raywenderlich.com/93997/ios-8-metal-tutorial-swift-part-3-adding-texture

class MetalTexture {
    var texture: MTLTexture!
    var target = MTLTextureType.type2D
    var width = 0
    var height = 0
    var depth = 1
    var format = MTLPixelFormat.rgba8Unorm
    var hasAlpha = false

    var path: String?
    var isMipmaped: Bool

    let bytesPerPixel = 4
    let bitsPerComponent = 8

    init(resourceName: String, ext: String, mipmaped: Bool) {
        path       = Bundle.main.path(forResource: resourceName, ofType: ext)
        isMipmaped = mipmaped
    }

    func loadTexture(_ device: MTLDevice, flip: Bool) {
        guard let image = UIImage(contentsOfFile: path!)?.cgImage else {
            return
        }

        width = image.width
        height = image.height

        // work around
        var alphaInfo = image.alphaInfo
        if alphaInfo == .last {
            alphaInfo = .premultipliedLast
        } else if alphaInfo == .first {
            alphaInfo = .premultipliedFirst
        }

        switch alphaInfo {
        case .none:               hasAlpha = false
        case .first:              hasAlpha = true
        case .last:               hasAlpha = true
        case .noneSkipFirst:      hasAlpha = false
        case .noneSkipLast:       hasAlpha = false
        case .alphaOnly:          hasAlpha = true
        case .premultipliedFirst: hasAlpha = true
        case .premultipliedLast:  hasAlpha = true
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rowBytes = width * bytesPerPixel
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: rowBytes, space: colorSpace,
            bitmapInfo: alphaInfo.rawValue)

        let bounds = CGRect(x: 0, y: 0, width: Int(width), height: Int(height))
        context?.clear(bounds)

        if flip == false {
            context?.translateBy(x: 0, y: CGFloat(self.height))
            context?.scaleBy(x: 1.0, y: -1.0)
        }

        context?.draw(image, in: bounds)

        let texDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: Int(width), height: Int(height), mipmapped: isMipmaped)
        target = texDescriptor.textureType
        texture = device.makeTexture(descriptor: texDescriptor)

        let pixelsData = context?.data
        let region = MTLRegionMake2D(0, 0, Int(width), Int(height))
        texture.replace(region: region, mipmapLevel: 0, withBytes: pixelsData!, bytesPerRow: Int(rowBytes))
    }

    func loadTexture(_ device: MTLDevice, commandQ: MTLCommandQueue, flip: Bool) {
        loadTexture(device, flip: flip)

        if isMipmaped == true {
            generateMipMapLayersUsingSystemFunc(texture, device: device, commandQ: commandQ, block: { (buffer) in
                print("mips generated")
            })
        }
    }

    func image(mipLevel: Int) -> UIImage {
        let p = bytesForMipLevel(mipLevel: mipLevel)
        let q = Int(powf(2, Float(mipLevel)))
        let mipmapedWidth = max(width / q, 1)
        let mipmapedHeight = max(height / q, 1)
        let rowBytes = mipmapedWidth * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: p, width: mipmapedWidth, height: mipmapedHeight, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        let imgRef = context?.makeImage()
        let image = UIImage(cgImage: imgRef!)
        return image
    }

    func image() -> UIImage {
        return image(mipLevel: 0)
    }

    func bytes() -> UnsafeMutableRawPointer {
        return bytesForMipLevel(mipLevel: 0)
    }

    func generateMipMapLayersUsingSystemFunc(
        _ texture: MTLTexture, device: MTLDevice, commandQ: MTLCommandQueue, block: @escaping MTLCommandBufferHandler) {
        let commandBuffer = commandQ.makeCommandBuffer()
        commandBuffer.addCompletedHandler(block)
        let blitCommandEncoder = commandBuffer.makeBlitCommandEncoder()
        blitCommandEncoder.generateMipmaps(for: texture)
        blitCommandEncoder.endEncoding()
        commandBuffer.commit()
    }

    private func bytesForMipLevel(mipLevel: Int) -> UnsafeMutableRawPointer {
        let q = Int(powf(2, Float(mipLevel)))
        let mipmapedWidth = max(Int(width) / q, 1)
        let mipmapedHeight = max(Int(height) / q, 1)
        let rowBytes = Int(mipmapedWidth * 4)
        let region = MTLRegionMake2D(0, 0, mipmapedWidth, mipmapedHeight)
        let pointer = malloc(rowBytes * mipmapedHeight)
        texture.getBytes(pointer!, bytesPerRow: rowBytes, from: region, mipmapLevel: mipLevel)
        return pointer!
    }
}
