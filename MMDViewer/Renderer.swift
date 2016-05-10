import Foundation
import UIKit
import GLKit

let kInFlightCommandBuffers = 3

func CreateOpaquePipelinesState(device: MTLDevice, _ vertexDescriptor: MTLVertexDescriptor, _ vertexFunc: MTLFunction, _ fragmentFunc: MTLFunction) -> MTLRenderPipelineState! {
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexFunc
    pipelineStateDescriptor.fragmentFunction = fragmentFunc
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
    pipelineStateDescriptor.depthAttachmentPixelFormat = .Depth32Float
    
    do {
        return try device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
    } catch {
        print("failure: device.newRenderPipelineStateWithDescriptor")
        return nil
    }
}

func CreateAlphaPipelinesState(device: MTLDevice, _ vertexDescriptor: MTLVertexDescriptor, _ vertexFunc: MTLFunction, _ fragmentFunc: MTLFunction) -> MTLRenderPipelineState! {
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    
    pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
    pipelineStateDescriptor.vertexFunction = vertexFunc
    pipelineStateDescriptor.fragmentFunction = fragmentFunc
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .BGRA8Unorm
    pipelineStateDescriptor.depthAttachmentPixelFormat = .Depth32Float
    
    let ca = pipelineStateDescriptor.colorAttachments[0]
    ca.blendingEnabled = true
    ca.rgbBlendOperation = .Add
    ca.alphaBlendOperation = .Add
    #if false
        ca.sourceRGBBlendFactor = .SourceAlpha
        ca.sourceAlphaBlendFactor = .SourceAlpha
    #else
        // expect image is PremultipliedLast
        ca.sourceRGBBlendFactor = .One
        ca.sourceAlphaBlendFactor = .One
    #endif
    ca.destinationRGBBlendFactor = .OneMinusSourceAlpha
    ca.destinationAlphaBlendFactor = .OneMinusSourceAlpha
    
    do {
        return try device.newRenderPipelineStateWithDescriptor(pipelineStateDescriptor)
    } catch {
        print("failure: device.newRenderPipelineStateWithDescriptor")
        return nil
    }
}

class Renderer {
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var shaderLibrary: MTLLibrary?
    
    private var commandBuffer: MTLCommandBuffer?
    var renderEncoder: MTLRenderCommandEncoder?
    
    var depthStencilState: MTLDepthStencilState?
    
    var worldModelMatrix = GLKMatrix4Identity
    var projectionMatrix = GLKMatrix4Identity
    
    private let inflightSemaphore: dispatch_semaphore_t
    private var mnOrientation = UIInterfaceOrientation.Unknown
    
    init() {
        inflightSemaphore = dispatch_semaphore_create(kInFlightCommandBuffers)
    }
    
    func configure(view: MMDView) {
        device = view.device;
        
        view.depthPixelFormat   = MTLPixelFormat.Depth32Float
        view.stencilPixelFormat = MTLPixelFormat.Invalid
        view.sampleCount        = 1
        
        commandQueue = device!.newCommandQueue()
        
        let sharedLibrary = device!.newDefaultLibrary()
        if sharedLibrary == nil {
            fatalError("failed to create a default shader library")
        }
        shaderLibrary = sharedLibrary
        
        if !prepareDepthStencilState() {
            fatalError("failed to create a depth stencil state")
        }
        
        worldModelMatrix = GLKMatrix4Identity.translate(0.0, y: -10.0, z: -20.0).rotateAroundX(GLKMathDegreesToRadians(0), y: 0.0, z: 0.0)
        projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(85.0), 1.0, 0.01, 100.0)
    }
    
    private func prepareDepthStencilState() -> Bool {
        let pDepthStateDesc = MTLDepthStencilDescriptor()
        pDepthStateDesc.depthCompareFunction = .Less
        pDepthStateDesc.depthWriteEnabled    = true
        depthStencilState = device!.newDepthStencilStateWithDescriptor(pDepthStateDesc)
        return true
    }
    
    func begin(view: MMDView) {
        commandBuffer = self.commandQueue!.commandBuffer()
        
        if let commandBuffer = commandBuffer {
            dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER)
            commandBuffer.addCompletedHandler { (commandBuffer) -> Void in
                dispatch_semaphore_signal(self.inflightSemaphore)
            }
            
            if let renderPassDescriptor = view.renderPassDescriptor {
                renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(renderPassDescriptor)
            }
        }
    }
    
    func end(view: MMDView) {
        if let drawable = view.currentDrawable {
            renderEncoder?.endEncoding()
            commandBuffer?.presentDrawable(drawable)
            commandBuffer?.commit()
        }
        
        commandBuffer = nil
        renderEncoder = nil
    }
    
    func reshape(view: MMDView) {
        let orientation = UIApplication.sharedApplication().statusBarOrientation
        
        if mnOrientation != orientation {
            mnOrientation = orientation;
            let aspect = Float(view.bounds.size.width / view.bounds.size.height)
            projectionMatrix = GLKMatrix4MakePerspective(
                GLKMathDegreesToRadians(85.0),
                aspect,
                0.01,
                100.0)
        }
    }
}
