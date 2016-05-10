import UIKit

// see http://www.raywenderlich.com/93997/ios-8-metal-tutorial-swift-part-3-adding-texture

class MetalTexture {
    var texture: MTLTexture!
    var target = MTLTextureType.Type2D
    var width = 0
    var height = 0
    var depth = 1
    var format = MTLPixelFormat.RGBA8Unorm
    var hasAlpha = false
    
    var path: String?
    var isMipmaped: Bool

    let bytesPerPixel = 4
    let bitsPerComponent = 8
    
    init(resourceName: String, ext: String, mipmaped: Bool) {
        path       = NSBundle.mainBundle().pathForResource(resourceName, ofType: ext)
        isMipmaped = mipmaped
    }
    
    func loadTexture(device: MTLDevice, flip: Bool) {
        let image = UIImage(contentsOfFile: path!)?.CGImage
        width = CGImageGetWidth(image)
        height = CGImageGetHeight(image)
        
        // work around
        var alphaInfo = CGImageGetAlphaInfo(image)
        if alphaInfo == .Last {
            alphaInfo = .PremultipliedLast
        } else if alphaInfo == .First {
            alphaInfo = .PremultipliedFirst
        }
        
        switch alphaInfo {
        case .None:               hasAlpha = false;
        case .First:              hasAlpha = true;
        case .Last:               hasAlpha = true;
        case .NoneSkipFirst:      hasAlpha = false;
        case .NoneSkipLast:       hasAlpha = false;
        case .Only:               hasAlpha = true;
        case .PremultipliedFirst: hasAlpha = true;
        case .PremultipliedLast:  hasAlpha = true;
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rowBytes = width * bytesPerPixel
        let context = CGBitmapContextCreate(
            nil, width, height, bitsPerComponent, rowBytes, colorSpace,
            alphaInfo.rawValue)
        
        let bounds = CGRect(x: 0, y: 0, width: Int(width), height: Int(height))
        CGContextClearRect(context, bounds)
        
        if flip == false {
            CGContextTranslateCTM(context, 0, CGFloat(self.height))
            CGContextScaleCTM(context, 1.0, -1.0)
        }
        
        CGContextDrawImage(context, bounds, image)
        
        let texDescriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(MTLPixelFormat.RGBA8Unorm, width: Int(width), height: Int(height), mipmapped: isMipmaped)
        target = texDescriptor.textureType
        texture = device.newTextureWithDescriptor(texDescriptor)
        
        let pixelsData = CGBitmapContextGetData(context)
        let region = MTLRegionMake2D(0, 0, Int(width), Int(height))
        texture.replaceRegion(region, mipmapLevel: 0, withBytes: pixelsData, bytesPerRow: Int(rowBytes))
    }
    
    func loadTexture(device: MTLDevice, commandQ: MTLCommandQueue, flip: Bool) {
        loadTexture(device, flip: flip)
        
        if isMipmaped == true {
            generateMipMapLayersUsingSystemFunc(texture, device: device, commandQ: commandQ, block: { (buffer) in
                print("mips generated")
            })
        }
    }
    
    func image(mipLevel mipLevel: Int) -> UIImage {
        let p = bytesForMipLevel(mipLevel: mipLevel)
        let q = Int(powf(2, Float(mipLevel)))
        let mipmapedWidth = max(width / q, 1)
        let mipmapedHeight = max(height / q, 1)
        let rowBytes = mipmapedWidth * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGBitmapContextCreate(
            p, mipmapedWidth, mipmapedHeight, 8, rowBytes, colorSpace,
            CGImageAlphaInfo.PremultipliedLast.rawValue 
        )
        let imgRef = CGBitmapContextCreateImage(context)
        let image = UIImage(CGImage: imgRef!)
        return image
    }
    
    func image() -> UIImage {
        return image(mipLevel: 0)
    }
    
    func bytes() -> UnsafeMutablePointer<Void> {
        return bytesForMipLevel(mipLevel: 0)
    }
    
    func generateMipMapLayersUsingSystemFunc(
        texture: MTLTexture, device: MTLDevice, commandQ: MTLCommandQueue, block: MTLCommandBufferHandler) {
        let commandBuffer = commandQ.commandBuffer()
        commandBuffer.addCompletedHandler(block)
        let blitCommandEncoder = commandBuffer.blitCommandEncoder()
        blitCommandEncoder.generateMipmapsForTexture(texture)
        blitCommandEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    private func bytesForMipLevel(mipLevel mipLevel: Int) -> UnsafeMutablePointer<Void> {
        let q = Int(powf(2, Float(mipLevel)))
        let mipmapedWidth = max(Int(width) / q, 1)
        let mipmapedHeight = max(Int(height) / q, 1)
        let rowBytes = Int(mipmapedWidth * 4)
        let region = MTLRegionMake2D(0, 0, mipmapedWidth, mipmapedHeight)
        let pointer = malloc(rowBytes * mipmapedHeight)
        texture.getBytes(pointer, bytesPerRow: rowBytes, fromRegion: region, mipmapLevel: mipLevel)
        return pointer
    }
}
