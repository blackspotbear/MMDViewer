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

/// shader が参照する行列群を 1 つの uniform buffer に詰める。
/// ここは Swift 側の行列表現と shader 側のメモリ配置が直接出会う境界なので、
/// `simd` 化を進める時も生バイト列の詰め方は別イテレーションで扱う。
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
    // SIMD3<Float> alignment is 16 bytes (= sizeof(Float) * 4)
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
        sampler.lodMaxClamp           = Float.greatestFiniteMagnitude
    } else {
        fatalError("failed creating a sampler descriptor")
    }

    return device.makeSamplerState(descriptor: pSamplerDescriptor!)!
}

private func PrepareDepthStencilState(_ device: MTLDevice) -> MTLDepthStencilState {
    let pDepthStateDesc = MTLDepthStencilDescriptor()
    pDepthStateDesc.depthCompareFunction = .less
    pDepthStateDesc.isDepthWriteEnabled    = true

    return device.makeDepthStencilState(descriptor: pDepthStateDesc)!
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

    /// ボーン原点を world へ押し出した結果。
    /// 物理ブリッジはこの値を基準に Bullet へ kinematic transform を送る。
    var worldPos: GLKVector3 {
        let p = wm.multiplyVector4(GLKVector4MakeWithVector3(bone.pos, 1))
        return GLKVector3Make(p.x, p.y, p.z)
    }

    /// 現在姿勢の world 回転。
    /// FK/IK/物理の各段が最終的にここへ畳み込まれる。
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
        var m = GLKMatrix4.translation(pos.x, pos.y, pos.z).multiply(
            GLKMatrix4.rotation(self.q).multiply(
                GLKMatrix4.translation(-bone.pos.x, -bone.pos.y, -bone.pos.z)
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
    let ambientColor: SIMD3<Float>
    let diffuseColor: SIMD3<Float>
    let specularColor: SIMD3<Float>
    let specularPower: Float
}

private struct RenderMatrices {
    let modelViewMatrix: GLKMatrix4
    let shadowMatrix: GLKMatrix4
    let shadowMatrixGB: GLKMatrix4
}

private struct PMXFrameRenderBuffers {
    let uniforms: MTLBuffer
    let matrixPalette: MTLBuffer
    let materials: MTLBuffer
}

private struct MorphFrameWeights {
    let left: Float
    let right: Float
}

private struct MorphKeyFramePair {
    let left: [VMDMorph]?
    let right: [VMDMorph]?
}

/// `PMXObject` が shader 向けに送る生バイト列の準備を集約する。
/// ここは still-legacy な `GLKMatrix4` 表現と `MTLBuffer` 書き込みが出会う境界で、
/// 後で別型へ切り出す時も呼び出し側の流れを崩さずに移行できるようにしている。
private enum PMXRenderDataEncoder {
    static func makeRenderMatrices(_ renderer: Renderer,
                                   _ modelMatrix: GLKMatrix4) -> RenderMatrices {
        let modelViewMatrix = renderer.viewMatrix.multiply(modelMatrix)
        let sunMatrix = GLKMatrix4.lookAt(
            eye: GLKVector3Make(-10, 12, 0),
            center: GLKVector3Make(0, 12, 0),
            up: GLKVector3Make(0, 1, 0)
        ) // right-handed
        let orthoMatrix = GLKMatrix4.orthographicOffCenter(
            left: -12, right: 12,
            bottom: -12, top: 12,
            near: 1, far: 20)
        let shadowMatrix = orthoMatrix.multiply(sunMatrix)
        let shadowMatrixGB = GLKMatrix4.translation(0.5, 0.5, 0.0)
            .multiply(GLKMatrix4.scale(0.5, -0.5, 1.0))
            .multiply(shadowMatrix)

        return RenderMatrices(
            modelViewMatrix: modelViewMatrix,
            shadowMatrix: shadowMatrix,
            shadowMatrixGB: shadowMatrixGB)
    }

    static func writeMatrixPalette(_ buffer: MTLBuffer, _ postures: [Posture]) {
        var dst = buffer.contents()

        for posture in postures {
            var worldMatrix = posture.wm
            memcpy(dst, &worldMatrix, MemoryLayout<GLKMatrix4>.size)
            dst = dst.advanced(by: MemoryLayout<GLKMatrix4>.stride)
        }
    }

    static func writeMaterials(_ buffer: MTLBuffer, _ materials: [Material]) {
        var materialPointer = buffer.contents()

        for mat in materials {
            var material = ShaderMaterial(
                ambientColor: SIMD3(mat.ambient.r, mat.ambient.g, mat.ambient.b),
                diffuseColor: SIMD3(mat.diffuse.r, mat.diffuse.g, mat.diffuse.b),
                specularColor: SIMD3(mat.specular.r, mat.specular.g, mat.specular.b),
                specularPower: mat.specularPower)
            memcpy(materialPointer, &material, MemoryLayout<ShaderMaterial>.size)
            materialPointer += MemoryLayout<ShaderMaterial>.stride
        }
    }
}

private func PhysicsSolverMake(_ pmx: PMX) -> PhysicsSolving {
    let solver = PhysicsSolverMake() as! PhysicsSolving

    solver.build(pmx.rigidBodies, constraints: pmx.constraints, bones: pmx.bones)

    return solver
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

    /// アプリ側の平行移動、回転、拡大縮小をまとめたモデル行列。
    /// ボーン姿勢とは別に、モデル全体をシーン内へ置くために使う。
    var modelMatrix: GLKMatrix4 {
        return GLKMatrix4Identity.scale(scale, y: scale, z: scale).rotateAroundX(rotationX, y: rotationY, z: rotationZ).translate(positionX, y: positionY, z: positionZ)
    }

    /// 法線用の行列。
    /// 現状は非一様スケールを使わない前提なので回転成分だけを抜き出している。
    var normalMatrix: GLKMatrix4 {
        return GLKMatrix4Identity.rotateAroundX(rotationX, y: rotationY, z: rotationZ)
    }

    private let vertexData: Data

    init(device: MTLDevice, pmx: PMX, vmd: VMD) {
        self.device = device
        self.pmx = pmx
        self.vmd = vmd

        self.curveTies = Self.makeCurveTies(pmx: pmx, vmd: vmd)
        self.postures = Self.makePostures(for: pmx.bones)

        vertexData = PMXVertex2NSData(pmx.vertices)!
        vertexBufferProvider = Self.makeVertexBufferProvider(device: device, vertexData: vertexData)
        indexBuffer = device.makeBuffer(bytes: pmx.indices, length: pmx.indices.count * MemoryLayout<UInt16>.size, options: MTLResourceOptions())!
        self.uniformBufferProvider = Self.makeUniformBufferProvider(device: device)
        self.mtrxBufferProvider = Self.makeMatrixPaletteBufferProvider(device: device, boneCount: pmx.bones.count)
        self.materialBufferProvider = Self.makeMaterialBufferProvider(device: device, materialCount: pmx.materials.count)
        self.textures = Self.loadTextures(device: device, texturePaths: pmx.texturePaths)

        counter = NormalCounter(beginFrameNum: 0, endFrameNum: vmd.meta.frameCount)
        //counter = DebugCounter(beginFrameNum: 160, endFrameNum: vmd.frameCount)

        solver = PhysicsSolverMake(pmx)
    }

    /// 1 frame 分のアニメーション、物理、morph、GPU 転送をまとめて進める。
    /// 呼び出し側は draw 前に毎フレームこれを実行する前提。
    func calc(_ renderer: Renderer) {
//        FKSolver(postures, vmd: vmd, frameNum: counter.currentFrame())
        updatePosturesForCurrentFrame()
        runPhysicsStep()
        prepareVertexBufferForCurrentFrame()
        updateRenderBuffers(renderer)
    }

    /// FK / IK / Grant 解決後に、全ボーンの world matrix を現在フレームへ揃える。
    /// 物理はこの結果を入力として受け取るため、姿勢計算のまとまりをここで固定する。
    private func updatePosturesForCurrentFrame() {
        FKSolver(postures, curveTies: self.curveTies, frameNum: counter.currentFrame())
        IKSolver(postures, maxIt: counter.maxIt())
        GrantSolver(postures)

        for posture in postures {
            posture.updateTransformMatrix(postures)
        }
    }

    /// FK/IK 後の姿勢を Bullet へ渡し、dynamic body の結果を posture へ戻す。
    private func runPhysicsStep() {
        PhysicsSolver(postures, physicsSolving: solver)
    }

    private static func makeCurveTies(pmx: PMX, vmd: VMD) -> [CurveTie] {
        var curveTies = [CurveTie](repeating: CurveTie(), count: pmx.bones.count)
        for (index, bone) in pmx.bones.enumerated() {
            if let tie = vmd.curveTies[bone.name] {
                curveTies[index] = tie
            }
        }
        return curveTies
    }

    private static func makePostures(for bones: [Bone]) -> [Posture] {
        return bones.map(Posture.init)
    }

    private static func makeVertexBufferProvider(device: MTLDevice, vertexData: Data) -> BufferProvider {
        return BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            data: vertexData)
    }

    private static func makeUniformBufferProvider(device: MTLDevice) -> BufferProvider {
        return BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<ShaderUniforms>.stride)
    }

    private static func makeMatrixPaletteBufferProvider(device: MTLDevice, boneCount: Int) -> BufferProvider {
        return BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<float4x4>.size * 4 * boneCount)
    }

    private static func makeMaterialBufferProvider(device: MTLDevice, materialCount: Int) -> BufferProvider {
        return BufferProvider(
            device: device,
            inflightBuffersCount: 3,
            sizeOfUniformsBuffer: MemoryLayout<ShaderMaterial>.stride * materialCount)
    }

    /// PMX の texture path をアプリ側 resource path へ解決して、Metal texture 群へ変換する。
    private static func loadTextures(device: MTLDevice, texturePaths: [String]) -> [MetalTexture] {
        return texturePaths.map { path in
            let ext = (path as NSString).pathExtension
            let body = (path as NSString).deletingPathExtension
            let texture = MetalTexture(resourceName: "data/mmd/" + body, ext: ext, mipmaped: false)
            texture.loadTexture(device, flip: true)
            return texture
        }
    }

    /// ベース頂点を inflight buffer へコピーし、現在フレームの morph を上書き適用する。
    /// CPU morph 実装の責務を `calc` 本体から切り離し、将来の GPU 化や計測をしやすくする。
    private func prepareVertexBufferForCurrentFrame() {
        currentVertexBuffer = vertexBufferProvider.nextBuffer()
        memcpy(currentVertexBuffer!.contents(), (vertexData as NSData).bytes, vertexData.count)
        applyMorph()
    }

    /// 頂点 morph を CPU 側 vertex buffer へ直接加算する。
    /// 現状は毎フレーム CPU で頂点を書き換える実装なので、性能改善候補でもある。
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

    /// 左右いずれかの morph key 群を 1 つの重みで適用する。
    /// 現状は vertex morph だけ CPU buffer へ反映し、他種別は将来の分離に備えて明示的に無視する。
    private func applyMorphKeyFrames(_ morphs: [VMDMorph], weightScale: Float) {
        for vm in morphs {
            guard let pm = morph(named: vm.name) else {
                continue
            }

            switch pm.type {
            case .vertex:
                updateVertex(pm, vm.weight * weightScale)
            case .group:
                break
            case .bone:
                break
            default:
                break
            }
        }
    }

    private func applyMorph() {
        let morphKeyFrames = currentMorphKeyFrames()
        if morphKeyFrames.left == nil && morphKeyFrames.right == nil {
            return
        }

        let weights = morphFrameWeights(leftMorphs: morphKeyFrames.left, rightMorphs: morphKeyFrames.right)

        if let ms = morphKeyFrames.left {
            applyMorphKeyFrames(ms, weightScale: weights.left)
        }

        if let ms = morphKeyFrames.right {
            applyMorphKeyFrames(ms, weightScale: weights.right)
        }
    }

    private func morph(named name: String) -> Morph? {
        return pmx.morphs[name]
    }

    /// 現在フレームの左右 keyframe 群をまとめて取り出す。
    /// `VMD` の返り値形式に `PMXObject` 全体を強く依存させないための薄い境界として扱う。
    private func currentMorphKeyFrames() -> MorphKeyFramePair {
        let morphs = vmd.getMorph(counter.currentFrame())
        return MorphKeyFramePair(left: morphs.left, right: morphs.right)
    }

    /// 左右 keyframe の時刻差から、現在フレームで適用する morph の寄与率を求める。
    /// morph 適用本体から補間重み計算を分離して、将来のテスト追加点を見つけやすくする。
    private func morphFrameWeights(leftMorphs: [VMDMorph]?, rightMorphs: [VMDMorph]?) -> MorphFrameWeights {
        let currentFrame = counter.currentFrame()
        let from = Float(leftMorphs != nil ? leftMorphs![0].frameNum : currentFrame)
        let to = Float(rightMorphs != nil ? rightMorphs![0].frameNum : currentFrame)
        let rightWeight = from == to ? 1 : (Float(currentFrame) - from) / (to - from)
        return MorphFrameWeights(left: 1 - rightWeight, right: rightWeight)
    }

    func updateCounter() {
        counter.increment()
    }

    /// draw が参照する 3 種類の buffer を 1 セットとして更新する。
    /// 呼び出し側はこの戻り値を保存するだけで、各 buffer の生成順を意識しなくてよい。
    private func makeFrameRenderBuffers(_ renderer: Renderer) -> PMXFrameRenderBuffers {
        return PMXFrameRenderBuffers(
            uniforms: makeUniformBuffer(renderer),
            matrixPalette: makeMatrixPaletteBuffer(),
            materials: makeMaterialBuffer())
    }

    /// 現在フレームの draw が参照する uniform / palette / material buffer を更新する。
    private func updateRenderBuffers(_ renderer: Renderer) {
        let renderBuffers = makeFrameRenderBuffers(renderer)
        store(renderBuffers)
    }

    private func store(_ renderBuffers: PMXFrameRenderBuffers) {
        uniformBuffer = renderBuffers.uniforms
        matrixPalette = renderBuffers.matrixPalette
        materialBuffer = renderBuffers.materials
    }

    /// 描画に必要な camera / shadow 行列をまとめて uniform buffer へ転送する。
    /// shadowMatrixGB は Metal のテクスチャ座標系に合わせて Y 反転込みで作っている。
    private func makeUniformBuffer(_ renderer: Renderer) -> MTLBuffer {
        let uniformBuffer = nextUniformBuffer()

        // "Metal Shading Language Guide" says:
        // In Metal, the origin of the pixel coordinate system of a texture is
        // defined at the top-left corner.
        //
        // So shadowMatrixGB's Y scale value is negative.
        //
        // see https://goo.gl/vgIYTf

        let renderMatrices = PMXRenderDataEncoder.makeRenderMatrices(renderer, modelMatrix)

        CopyMatrices(
            uniformBuffer,
            modelMatrix,
            renderMatrices.modelViewMatrix,
            renderer.projectionMatrix,
            normalMatrix,
            renderMatrices.shadowMatrix,
            renderMatrices.shadowMatrixGB)

        return uniformBuffer
    }

    /// 各ボーンの world matrix を matrix palette buffer へ詰める。
    /// shader 側の skinning はこの palette を前提にしている。
    private func makeMatrixPaletteBuffer() -> MTLBuffer {
        let palette = nextMatrixPaletteBuffer()
        PMXRenderDataEncoder.writeMatrixPalette(palette, postures)

        return palette
    }

    /// material ごとの色パラメータを shader 用の連続領域へ詰める。
    /// texture index や sphere map などは別経路で扱うため、ここでは色だけ送る。
    private func makeMaterialBuffer() -> MTLBuffer {
        let materialBuffer = nextMaterialBuffer()
        PMXRenderDataEncoder.writeMaterials(materialBuffer, pmx.materials)

        return materialBuffer
    }

    private func nextUniformBuffer() -> MTLBuffer {
        return uniformBufferProvider.nextBuffer()
    }

    private func nextMatrixPaletteBuffer() -> MTLBuffer {
        return mtrxBufferProvider.nextBuffer()
    }

    private func nextMaterialBuffer() -> MTLBuffer {
        return materialBufferProvider.nextBuffer()
    }
}
