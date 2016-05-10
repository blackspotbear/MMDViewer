import Foundation
import GLKit

protocol AnimationCounter {
    init(beginFrameNum: Int, endFrameNum: Int)
    func increment()
    func currentFrame() -> Int
    func maxIt() -> Int
}

private func CopyMatrices(buffer: MTLBuffer, _ modelViewMatrix: GLKMatrix4, _ projectionMatrix: GLKMatrix4, _ normalMatrix: GLKMatrix4) {
    let matrixBufferSize = sizeof(Float) * GLKMatrix4.numberOfElements()
    var dst = buffer.contents()
    
    memcpy(dst, modelViewMatrix.raw(), matrixBufferSize)
    dst = dst.advancedBy(matrixBufferSize)
    
    memcpy(dst, projectionMatrix.raw(), matrixBufferSize)
    dst = dst.advancedBy(matrixBufferSize)
    
    // shader's normal matrix is of type float3x3
    // float3 alignment is 16byte (= sizeof(Float) * 4)
    memcpy(dst, normalMatrix.raw(), sizeof(Float) * (4 * 3))
}

private class NormalCounter: AnimationCounter {
    let beginFrameNum: Int
    let endFrameNum: Int
    var frameNum: Int
    
    required init(beginFrameNum: Int, endFrameNum: Int) {
        self.beginFrameNum = beginFrameNum
        self.endFrameNum = endFrameNum
        frameNum = self.beginFrameNum
    }
    
    func increment() {
        frameNum += 1
        if frameNum >= endFrameNum {
            frameNum = beginFrameNum
        }
    }
    
    func currentFrame() -> Int {
        return frameNum
    }
    
    func maxIt() -> Int {
        return -1;
    }
}

private class DebugCounter: AnimationCounter {
    let beginFrameNum: Int
    let endFrameNum: Int
    var frameNum: Int
    
    var slowNum = 0
    var iterateNum = 0
    
    required init(beginFrameNum: Int, endFrameNum: Int) {
        self.beginFrameNum = beginFrameNum
        self.endFrameNum = endFrameNum
        frameNum = self.beginFrameNum
    }
    
    func increment() {
        slowNum += 1
        if slowNum >= 10 {
            slowNum = 0
            
            iterateNum += 1
            if iterateNum >= 5 {
                iterateNum = 0
                
                frameNum += 1
                if frameNum >= endFrameNum {
                    frameNum = beginFrameNum
                }
            }
        }
    }
    
    func currentFrame() -> Int {
        return frameNum
    }
    
    func maxIt() -> Int {
        return iterateNum;
    }
}

class Posture {
    let bone: Bone
    
    var q: GLKQuaternion
    var pos: GLKVector3
    var wm: GLKMatrix4 // world matrix
    
    var worldPos: GLKVector3 {
        let p = GLKMatrix4MultiplyVector4(wm, GLKVector4MakeWithVector3(bone.pos, 1))
        return GLKVector3Make(p.x, p.y, p.z)
    }
    
    var worldRot: GLKQuaternion {
        return GLKQuaternionMakeWithMatrix4(wm)
    }
    
    init(bone: Bone) {
        self.bone = bone
        q = GLKQuaternionIdentity
        pos = GLKVector3Make(0, 0, 0)
        wm = GLKMatrix4Identity
    }
    
    func reset() {
        q = GLKQuaternionIdentity
        pos = GLKVector3Make(0, 0, 0)
        wm = GLKMatrix4Identity
    }
    
    func updateTransformMatrix(postures: [Posture]) {
        var m = GLKMatrix4Multiply(
            GLKMatrix4MakeTranslation(pos.x, pos.y, pos.z),
            GLKMatrix4Multiply(
                GLKMatrix4MakeWithQuaternion(self.q),
                GLKMatrix4MakeTranslation(-bone.pos.x, -bone.pos.y, -bone.pos.z)
            )
        )
        if self.bone.parentBoneIndex < postures.count {
            m = postures[self.bone.parentBoneIndex].wm.multiply(m)
        }
        wm = m;
    }
}

private struct ShaderUniforms {
    let modelViewMatrix: float4x4
    let projectionMatrix: float4x4
    let normalMatrix: float4x4
    
    static var alignment: Int {
        let floatSize = sizeof(Float)
        let float3Size = floatSize * 4 // _4_
        let float4x4ByteAlignment = floatSize * 4
        let float4x4Size = floatSize * 16
        let float3x3Size = float3Size * 3
        let uniformStructDataSize = float4x4Size * 2 + float3x3Size
        let paddingBytesSize = float4x4ByteAlignment - (uniformStructDataSize % float4x4ByteAlignment)
        return uniformStructDataSize + paddingBytesSize
    }
};

private struct ShaderMaterial {
    let ambientColor: float3
    let diffuseColor: float3
    let specularColor: float3
    let specularPower: Float
    
    static var alignment: Int {
        let materialPadding = sizeof(float3) - (sizeof(ShaderMaterial) % sizeof(float3))
        return sizeof(ShaderMaterial) + materialPadding
    }
}

class PMXModel {
    var device: MTLDevice
    var pmx: PMX
    var vmd: VMD
    
    var indexBuffer: MTLBuffer
    var opaquePipelineState: MTLRenderPipelineState?
    var alphaPipelineState: MTLRenderPipelineState?
    
    var positionX: Float = 0
    var positionY: Float = 0
    var positionZ: Float = 0
    var rotationX: Float = 0
    var rotationY: Float = 0
    var rotationZ: Float = 0
    var scale: Float = 1
    
    var vertexBufferProvider: BufferProvider
    var uniformBufferProvider: BufferProvider
    var mtrxBufferProvider: BufferProvider
    var materialBufferProvider: BufferProvider
    var currentVertexBuffer: MTLBuffer?
    
    var textures: [MetalTexture] = []
    lazy var samplerState: MTLSamplerState = PMXModel.defaultSampler(self.device)
    
    let counter: AnimationCounter
    
    var postures: [Posture] = []
    
    var modelMatrix: GLKMatrix4 {
        return GLKMatrix4Identity.scale(scale, y: scale, z: scale).rotateAroundX(rotationX, y: rotationY, z: rotationZ).translate(positionX, y: positionY, z: positionZ)
    }
    
    var normalMatrix: GLKMatrix4 {
        return GLKMatrix4Identity.rotateAroundX(rotationX, y: rotationY, z: rotationZ)
    }
    
    class func defaultSampler(device: MTLDevice) -> MTLSamplerState {
        let pSamplerDescriptor:MTLSamplerDescriptor? = MTLSamplerDescriptor();

        if let sampler = pSamplerDescriptor {
            sampler.minFilter             = .Linear
            sampler.magFilter             = .Linear
            sampler.mipFilter             = .Linear
            sampler.maxAnisotropy         = 1
            sampler.sAddressMode          = .Repeat
            sampler.tAddressMode          = .Repeat
            sampler.rAddressMode          = .Repeat
            sampler.normalizedCoordinates = true
            sampler.lodMinClamp           = 0
            sampler.lodMaxClamp           = FLT_MAX
        } else {
            fatalError("failed creating a sampler descriptor")
        }
        
        return device.newSamplerStateWithDescriptor(pSamplerDescriptor!)
    }
    
    private let vertexData: NSData
    
    private func initPipelineState(device: MTLDevice) {
        let defaultLibrary = device.newDefaultLibrary()
        let newVertexFunction = defaultLibrary!.newFunctionWithName("basic_vertex")
        let newFragmentFunction = defaultLibrary?.newFunctionWithName("basic_fragment")
        
        // Define vertex layout
        let vertexDescriptor = MTLVertexDescriptor()
        // position
        vertexDescriptor.attributes[0].offset = 0;
        vertexDescriptor.attributes[0].format = .Float3
        vertexDescriptor.attributes[0].bufferIndex = 0
        // normal
        vertexDescriptor.attributes[1].offset = sizeof(Float32) * 3
        vertexDescriptor.attributes[1].format = .Float3
        vertexDescriptor.attributes[1].bufferIndex = 0
        // uv
        vertexDescriptor.attributes[2].offset = sizeof(Float32) * 6
        vertexDescriptor.attributes[2].format = .Float2
        vertexDescriptor.attributes[2].bufferIndex = 0
        // layout
        vertexDescriptor.layouts[0].stepFunction = .PerVertex
        vertexDescriptor.layouts[0].stride = sizeof(Float32) * (3 + 3 + 2)
        
        opaquePipelineState = CreateOpaquePipelinesState(device, vertexDescriptor, newVertexFunction!, newFragmentFunction!)
        alphaPipelineState = CreateAlphaPipelinesState(device, vertexDescriptor, newVertexFunction!, newFragmentFunction!)
    }
    
    init(device: MTLDevice, pmx: PMX, vmd: VMD) {
        self.device = device
        self.pmx = pmx
        self.vmd = vmd
        
        for i in 0..<self.pmx.bones.count {
            let posture = Posture(bone: self.pmx.bones[i])
            self.postures.append(posture)
        }
        
        vertexData = PMXVertex2NSData(pmx.vertices)!
        vertexBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            data: vertexData)
        
        indexBuffer = device.newBufferWithBytes(pmx.indices, length: pmx.indices.count * sizeof(UInt16), options: .CPUCacheModeDefaultCache)

        self.uniformBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: ShaderUniforms.alignment)
        
        let float4x4Size = sizeof(Float) * 16
        self.mtrxBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: float4x4Size * 4 * pmx.bones.count)
        
        self.materialBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: ShaderMaterial.alignment * pmx.materials.count)
        
        for path in pmx.texturePaths {
            let ext = (path as NSString).pathExtension
            let body = (path as NSString).stringByDeletingPathExtension
            let texture = MetalTexture(resourceName: "data/mmd/" + body, ext: ext, mipmaped: false)
            texture.loadTexture(device, flip: true)
            textures.append(texture)
        }
        
        counter = NormalCounter(beginFrameNum: 0, endFrameNum: vmd.meta.frameCount)
        //counter = DebugCounter(beginFrameNum: 160, endFrameNum: vmd.frameCount)
        
        initPipelineState(device)
    }
    
    func calc() {
        FKSolver(postures, vmd: vmd, frameNum: counter.currentFrame())
        IKSolver(postures, maxIt: counter.maxIt())
        GrantSolver(postures)
        
        for posture in postures {
            posture.updateTransformMatrix(postures)
        }
        
        currentVertexBuffer = vertexBufferProvider.nextBuffer()
        memcpy(currentVertexBuffer!.contents(), vertexData.bytes, vertexData.length)
        
        applyMorph()
    }
    
    private func updateVertex(morph: Morph, _ weight: Float) {
        let p = currentVertexBuffer!.contents()
        let size = PMXVertex.packedSize
        for e in morph.elements {
            let ev = e as! MorphVertex
            var fp = UnsafeMutablePointer<Float>(p.advancedBy(size * ev.index))
            fp.memory += ev.trans.x * weight; fp = fp.advancedBy(1)
            fp.memory += ev.trans.y * weight; fp = fp.advancedBy(1)
            fp.memory += ev.trans.z * weight; fp = fp.advancedBy(1)
        }
    }
    
    private func applyMorph() {
        let morphs = vmd.getMorph(counter.currentFrame())
        if morphs.left == nil && morphs.right == nil {
            return
        }
        
        let from = Float(morphs.left != nil ? morphs.left![0].frameNum : counter.currentFrame())
        let to = Float(morphs.right != nil ? morphs.right![0].frameNum : counter.currentFrame())
        let t = from == to ? 1 : (Float(counter.currentFrame()) - from) / (to - from)
        
        if let ms = morphs.left {
            for vm in ms {
                if let pm = pmx.morphs[vm.name] {
                    if pm.type != .Vertex {
                        print("mumumu!")
                    }
                    switch pm.type {
                    case .Vertex: updateVertex(pm, vm.weight * (1 - t))
                    case .Group: break
                    case .Bone: break;
                    default: break
                    }
                }
            }
        }
        
        if let ms = morphs.right {
            for vm in ms {
                if let pm = pmx.morphs[vm.name] {
                    if pm.type != .Vertex {
                        print("mumumu!")
                    }
                    switch(pm.type) {
                    case .Vertex: updateVertex(pm, vm.weight * t)
                    case .Group: break
                    case .Bone: break;
                    default: break
                    }
                }
            }
        }
    }
    
    func updateCounter() {
        counter.increment()
    }
    
    private func sendUniforms(renderer: Renderer) -> MTLBuffer {
        let uniformBuffer = uniformBufferProvider.nextBuffer()
        let nodeModelMatrix = modelMatrix.multiplyLeft(renderer.worldModelMatrix)
        CopyMatrices(uniformBuffer, nodeModelMatrix, renderer.projectionMatrix, normalMatrix)
        return uniformBuffer
    }
    
    private func sendMatrixPalette() -> MTLBuffer {
        let palette = self.mtrxBufferProvider.nextBuffer()
        let matrixBufferSize = sizeof(Float) * 16
        var dst = palette.contents()
        
        for i in 0 ..< postures.count {
            memcpy(dst, postures[i].wm.raw(), matrixBufferSize)
            dst = dst.advancedBy(matrixBufferSize)
        }
        
        return palette
    }
    
    private func sendMaterials() -> MTLBuffer {
        let materialBuffer = materialBufferProvider.nextBuffer()
        
        var materialPointer = materialBuffer.contents()
        for mat in pmx.materials {
            var material = ShaderMaterial(
                ambientColor: float3(mat.ambient.r, mat.ambient.g, mat.ambient.b),
                diffuseColor: float3(mat.diffuse.r, mat.diffuse.g, mat.diffuse.b),
                specularColor: float3(mat.specular.r, mat.specular.g, mat.specular.b),
                specularPower: mat.specularPower)
            memcpy(materialPointer, &material, sizeof(ShaderMaterial))
            materialPointer += ShaderMaterial.alignment
        }
        
        return materialBuffer
    }
    
    func render(renderer: Renderer) {
        if renderer.renderEncoder == nil {
            return
        }
        
        let renderEncoder = renderer.renderEncoder!
        
        renderEncoder.setCullMode(MTLCullMode.Front)
        renderEncoder.setDepthStencilState(renderer.depthStencilState)
        
        let uniformBuffer = sendUniforms(renderer)
        let matrixPalette = sendMatrixPalette()
        let materialBuffer = sendMaterials()
        
        renderEncoder.setVertexBuffer(currentVertexBuffer!, offset: 0, atIndex: 0)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, atIndex: 1)
        renderEncoder.setVertexBuffer(matrixPalette, offset: 0, atIndex: 2)
        
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, atIndex:0)
        renderEncoder.setFragmentSamplerState(samplerState, atIndex: 0)
        
        // draw primitieves for each material
        var indexByteOffset = 0
        var materialByteOffset = 0
        for material in pmx.materials {
            let textureIndex = material.textureIndex != 255 ? material.textureIndex : 0
            let texture = textures[textureIndex]
            let renderPipelineState = (texture.hasAlpha ?? false) ? alphaPipelineState! : opaquePipelineState!
            
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setFragmentTexture(texture.texture, atIndex: 0)
            renderEncoder.setFragmentBuffer(materialBuffer, offset: materialByteOffset, atIndex: 1)
            
            renderEncoder.drawIndexedPrimitives(
                .Triangle,
                indexCount: Int(material.vertexCount),
                indexType: .UInt16,
                indexBuffer: indexBuffer,
                indexBufferOffset: indexByteOffset)
            
            indexByteOffset += Int(material.vertexCount) * 2 // 2 bytes per index
            materialByteOffset += ShaderMaterial.alignment
        }
    }
}