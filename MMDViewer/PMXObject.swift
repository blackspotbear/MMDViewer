import Foundation
import GLKit
import Metal
import simd

protocol AnimationCounter {
    init(beginFrameNum: Int, endFrameNum: Int)
    func increment()
    func currentFrame() -> Int
    func maxIt() -> Int
}

private func CopyMatrices(_ buffer: MTLBuffer,
                          _ modelMatrix: GLKMatrix4,
                          _ modelViewMatrix: GLKMatrix4,
                          _ projectionMatrix: GLKMatrix4,
                          _ normalMatrix: GLKMatrix4,
                          _ shadowMatrix: GLKMatrix4,
                          _ shadowMatrixGB: GLKMatrix4) {
    let matrixBufferSize = MemoryLayout<GLKMatrix4>.stride
    var dst = buffer.contents()

    var modelMatrix = modelMatrix
    var modelViewMatrix = modelViewMatrix
    var projectionMatrix = projectionMatrix
    var shadowMatrix = shadowMatrix
    var shadowMatrixGB = shadowMatrixGB
    var normalMatrix = normalMatrix

    memcpy(dst, &modelMatrix, matrixBufferSize)
    dst = dst.advanced(by: matrixBufferSize)

    memcpy(dst, &modelViewMatrix, matrixBufferSize)
    dst = dst.advanced(by: matrixBufferSize)

    memcpy(dst, &projectionMatrix, matrixBufferSize)
    dst = dst.advanced(by: matrixBufferSize)

    memcpy(dst, &shadowMatrix, matrixBufferSize)
    dst = dst.advanced(by: matrixBufferSize)

    memcpy(dst, &shadowMatrixGB, matrixBufferSize)
    dst = dst.advanced(by: matrixBufferSize)

    // shader's normal matrix is of type float3x3
    // float3 alignment is 16byte (= sizeof(Float) * 4)
    memcpy(dst, &normalMatrix, MemoryLayout<float3x3>.size)
}

private func DefaultSampler(_ device: MTLDevice) -> MTLSamplerState {
    let pSamplerDescriptor: MTLSamplerDescriptor? = MTLSamplerDescriptor()

    if let sampler = pSamplerDescriptor {
        sampler.minFilter             = .linear
        sampler.magFilter             = .linear
        sampler.mipFilter             = .linear
        sampler.maxAnisotropy         = 1
        sampler.sAddressMode          = .repeat
        sampler.tAddressMode          = .repeat
        sampler.rAddressMode          = .repeat
        sampler.normalizedCoordinates = true
        sampler.lodMinClamp           = 0
        sampler.lodMaxClamp           = FLT_MAX
    } else {
        fatalError("failed creating a sampler descriptor")
    }

    return device.makeSamplerState(descriptor: pSamplerDescriptor!)
}

private func PrepareDepthStencilState(_ device: MTLDevice) -> MTLDepthStencilState {
    let pDepthStateDesc = MTLDepthStencilDescriptor()
    pDepthStateDesc.depthCompareFunction = .less
    pDepthStateDesc.isDepthWriteEnabled    = true

    return device.makeDepthStencilState(descriptor: pDepthStateDesc)
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
        return -1
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
        return iterateNum
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

    func updateTransformMatrix(_ postures: [Posture]) {
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
        wm = m
    }
}

struct ShaderUniforms {
    let modelMatrix: float4x4
    let modelViewMatrix: float4x4
    let projectionMatrix: float4x4
    let shadowMatrix: float4x4
    let shadowMatrixGB: float4x4
    let normalMatrix: float3x3
}

struct ShaderMaterial {
    let ambientColor: float3
    let diffuseColor: float3
    let specularColor: float3
    let specularPower: Float
}

private func PhysicsSolverMake(_ pmx: PMX) -> PhysicsSolving {
    let solver = PhysicsSolverMake() as! PhysicsSolving

    solver.build(pmx.rigidBodies, constraints: pmx.constraints, bones: pmx.bones)

    return solver
}

// Make right-handed orthographic matrix.
//
// right-handed: 10-th value of matrix has a negative sign.
// "OC" stands for off-center.
//
// see http://www.songho.ca/opengl/gl_projectionmatrix.html#ortho
// and https://goo.gl/lJ1fb3 , https://goo.gl/Xlqrwf
// and https://goo.gl/lD41Z7 , https://goo.gl/zqBkCU
private func MakeOrthoOC(_ left: Float, _ right: Float, _ bottom: Float, _ top: Float, _ near: Float, _ far: Float) -> GLKMatrix4 {
    let sLength = 1.0 / (right - left)
    let sHeight = 1.0 / (top   - bottom)
    let sDepth  = 1.0 / (far   - near)

    // "Metal Programming Guide" says:
    // Metal defines its Normalized Device Coordinate (NDC) system as a 2x2x1 cube
    // with its center at (0, 0, 0.5). The left and bottom for x and y, respectively,
    // of the NDC system are specified as -1. The right and top for x and y, respectively,
    // of the NDC system are specified as +1.
    //
    // see https://goo.gl/5wT5kg

    // Because of the reason, following formula is defferent from https://goo.gl/rFN8eS .
    return GLKMatrix4Make(
         2.0 * sLength,             0.0,                       0.0,            0.0,
         0.0,                       2.0 * sHeight,             0.0,            0.0,
         0.0,                       0.0,                      -sDepth,         0.0,
        -sLength * (left + right), -sHeight * (top + bottom), -sDepth  * near, 1.0)
}

class PMXObject {
    var device: MTLDevice
    var pmx: PMX
    var vmd: VMD
    var curveTies: [CurveTie]

    var indexBuffer: MTLBuffer
    var uniformBuffer: MTLBuffer?
    var matrixPalette: MTLBuffer?
    var materialBuffer: MTLBuffer?

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
    lazy var samplerState: MTLSamplerState = DefaultSampler(self.device)
    lazy var depthStencilState: MTLDepthStencilState = PrepareDepthStencilState(self.device)

    let counter: AnimationCounter

    let solver: PhysicsSolving

    var postures: [Posture] = []

    var modelMatrix: GLKMatrix4 {
        return GLKMatrix4Identity.scale(scale, y: scale, z: scale).rotateAroundX(rotationX, y: rotationY, z: rotationZ).translate(positionX, y: positionY, z: positionZ)
    }

    var normalMatrix: GLKMatrix4 {
        return GLKMatrix4Identity.rotateAroundX(rotationX, y: rotationY, z: rotationZ)
    }

    private let vertexData: Data

    init(device: MTLDevice, pmx: PMX, vmd: VMD) {
        self.device = device
        self.pmx = pmx
        self.vmd = vmd

        self.curveTies = [CurveTie](repeating: CurveTie(), count: pmx.bones.count)
        for (i, bone) in self.pmx.bones.enumerated() {
            if let tie = self.vmd.curveTies[bone.name] {
                self.curveTies[i] = tie
            }
        }

        for i in 0..<self.pmx.bones.count {
            let posture = Posture(bone: self.pmx.bones[i])
            self.postures.append(posture)
        }

        vertexData = PMXVertex2NSData(pmx.vertices)!
        vertexBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            data: vertexData)

        indexBuffer = device.makeBuffer(bytes: pmx.indices, length: pmx.indices.count * MemoryLayout<UInt16>.size, options: MTLResourceOptions())

        self.uniformBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<ShaderUniforms>.stride)

        self.mtrxBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<float4x4>.size * 4 * pmx.bones.count)

        self.materialBufferProvider = BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<ShaderMaterial>.stride * pmx.materials.count)

        for path in pmx.texturePaths {
            let ext = (path as NSString).pathExtension
            let body = (path as NSString).deletingPathExtension
            let texture = MetalTexture(resourceName: "data/mmd/" + body, ext: ext, mipmaped: false)
            texture.loadTexture(device, flip: true)
            textures.append(texture)
        }

        counter = NormalCounter(beginFrameNum: 0, endFrameNum: vmd.meta.frameCount)
        //counter = DebugCounter(beginFrameNum: 160, endFrameNum: vmd.frameCount)

        solver = PhysicsSolverMake(pmx)
    }

    func calc(_ renderer: Renderer) {
//        FKSolver(postures, vmd: vmd, frameNum: counter.currentFrame())
        FKSolver(postures, curveTies: self.curveTies, frameNum: counter.currentFrame())
        IKSolver(postures, maxIt: counter.maxIt())
        GrantSolver(postures)

        for posture in postures {
            posture.updateTransformMatrix(postures)
        }

        PhysicsSolver(postures, physicsSolving: solver)

        currentVertexBuffer = vertexBufferProvider.nextBuffer()
        memcpy(currentVertexBuffer!.contents(), (vertexData as NSData).bytes, vertexData.count)

        applyMorph()

        uniformBuffer = sendUniforms(renderer)
        matrixPalette = sendMatrixPalette()
        materialBuffer = sendMaterials()
    }

    private func updateVertex(_ morph: Morph, _ weight: Float) {
        let p = currentVertexBuffer!.contents()
        let size = PMXVertex.packedSize
        for e in morph.elements {
            let ev = e as! MorphVertex
            var fp = p.advanced(by: size * ev.index).assumingMemoryBound(to: Float.self)
            fp.pointee += ev.trans.x * weight; fp = fp.advanced(by: 1)
            fp.pointee += ev.trans.y * weight; fp = fp.advanced(by: 1)
            fp.pointee += ev.trans.z * weight; fp = fp.advanced(by: 1)
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
                    switch pm.type {
                    case .vertex: updateVertex(pm, vm.weight * (1 - t))
                    case .group: break
                    case .bone: break
                    default: break
                    }
                }
            }
        }

        if let ms = morphs.right {
            for vm in ms {
                if let pm = pmx.morphs[vm.name] {
                    switch pm.type {
                    case .vertex: updateVertex(pm, vm.weight * t)
                    case .group: break
                    case .bone: break
                    default: break
                    }
                }
            }
        }
    }

    func updateCounter() {
        counter.increment()
    }

    private func sendUniforms(_ renderer: Renderer) -> MTLBuffer {
        let uniformBuffer = uniformBufferProvider.nextBuffer()

        // "Metal Shading Language Guide" says:
        // In Metal, the origin of the pixel coordinate system of a texture is
        // defined at the top-left corner.
        //
        // So shadowMatrixGB's Y scale value is negative.
        //
        // see https://goo.gl/vgIYTf

        let modelViewMatrix = renderer.viewMatrix.multiply(modelMatrix)
        let sunMatrix = GLKMatrix4MakeLookAt(-10, 12, 0, 0, 12, 0, 0, 1, 0) // right-handed
        let orthoMatrix = MakeOrthoOC(-12, 12, -12, 12, 1, 20)
        let shadowMatrix = orthoMatrix.multiply(sunMatrix)
        let shadowMatrixGB = GLKMatrix4MakeTranslation(0.5, 0.5, 0.0).multiply(GLKMatrix4MakeScale(0.5, -0.5, 1.0)).multiply(shadowMatrix)

        CopyMatrices(
            uniformBuffer,
            modelMatrix,
            modelViewMatrix,
            renderer.projectionMatrix,
            normalMatrix,
            shadowMatrix,
            shadowMatrixGB)

        return uniformBuffer
    }

    private func sendMatrixPalette() -> MTLBuffer {
        let palette = self.mtrxBufferProvider.nextBuffer()
        var dst = palette.contents()

        for posture in postures {
            memcpy(dst, posture.wm.raw(), MemoryLayout<GLKMatrix4>.size)
            dst = dst.advanced(by: MemoryLayout<GLKMatrix4>.stride)
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
            memcpy(materialPointer, &material, MemoryLayout<ShaderMaterial>.size)
            materialPointer += MemoryLayout<ShaderMaterial>.stride
        }

        return materialBuffer
    }
}
