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

private struct MorphUpdate {
    let morph: Morph
    let weight: Float
}

private struct PMXAnimationTick {
    let frameNumber: Int
    let maxIterations: Int
}

private struct PMXFrameContext {
    let animation: PMXAnimationContext
    let render: PMXRenderContext
}

private struct PMXRenderUpdateContext {
    let render: PMXRenderContext
}

private struct PMXFrameUpdateSession {
    let animation: PMXAnimationUpdateContext
    let geometry: PMXGeometryUpdateContext
    let render: PMXRenderUpdateContext
}

private struct PMXFramePipelineSession {
    let context: PMXFrameContext
    let update: PMXFrameUpdateSession
}

private struct PMXAnimationContext {
    let tick: PMXAnimationTick
}

private struct PMXAnimationUpdateContext {
    let animation: PMXAnimationContext
}

private struct PMXAnimationUpdateSession {
    let context: PMXAnimationUpdateContext
}

private struct PMXGeometryContext {
    let tick: PMXAnimationTick
    let vertexBuffer: MTLBuffer
}

private struct PMXGeometryUpdateContext {
    let geometry: PMXGeometryContext
}

private struct PMXGeometryUpdateSession {
    let context: PMXGeometryUpdateContext
}

private struct PMXRenderContext {
    let renderer: Renderer
    let transforms: PMXModelTransforms
}

private struct PMXModelTransforms {
    let modelMatrix: GLKMatrix4
    let normalMatrix: GLKMatrix4
}

private struct PMXMorphFrameContext {
    let frames: MorphKeyFramePair
    let weights: MorphFrameWeights
}

private struct PMXMorphApplicationContext {
    let frame: PMXMorphFrameContext
}

private struct PMXMorphResolutionSession {
    let updates: PMXMorphUpdates
}

private struct PMXMorphFrameResolutionSession {
    let frame: PMXMorphFrameContext
    let updates: PMXMorphUpdates
}

private struct PMXMorphApplicationSession {
    let updates: [MorphUpdate]
}

private struct PMXMorphPipelineSession {
    let application: PMXMorphApplicationSession
}

private struct PMXObjectResources {
    let vertexData: Data
    let bufferProviders: PMXBufferProviders
    let indexBuffer: MTLBuffer
    let textures: [MetalTexture]
}

private struct PMXObjectAnimationState {
    let curveTies: [CurveTie]
    let postures: [Posture]
    let counter: AnimationCounter
    let solver: PhysicsSolving
}

private struct PMXBufferProviders {
    let vertex: BufferProvider
    let uniforms: BufferProvider
    let matrixPalette: BufferProvider
    let materials: BufferProvider
}

private struct PMXObjectSetup {
    let resources: PMXObjectResources
    let animationState: PMXObjectAnimationState
}

private struct PMXMorphUpdates {
    let left: [MorphUpdate]
    let right: [MorphUpdate]
}

private struct PMXStoredRenderBuffers {
    let uniformBuffer: MTLBuffer
    let matrixPalette: MTLBuffer
    let materialBuffer: MTLBuffer
}

private struct PMXRenderBufferStorageSession {
    let buffers: PMXStoredRenderBuffers
}

private struct PMXRenderBufferStorageApplySession {
    let storage: PMXStoredRenderBuffers
}

private struct PMXFrameRenderBufferAssembly {
    let buffers: PMXFrameRenderBuffers
}

private struct PMXRenderBufferComponentSession {
    let uniforms: MTLBuffer
    let matrixPalette: MTLBuffer
    let materials: MTLBuffer
}

private struct PMXUniformBufferSession {
    let buffer: MTLBuffer
    let renderMatrices: RenderMatrices
}

private struct PMXMatrixPaletteBufferSession {
    let buffer: MTLBuffer
}

private struct PMXMaterialBufferSession {
    let buffer: MTLBuffer
}

private struct PMXRenderBufferUpdateSession {
    let assembly: PMXFrameRenderBufferAssembly
}

private struct PMXRenderBufferApplySession {
    let buffers: PMXFrameRenderBuffers
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

    private var bufferProviders: PMXBufferProviders
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

        let setup = Self.makeSetup(device: device, pmx: pmx, vmd: vmd)
        vertexData = setup.resources.vertexData
        bufferProviders = setup.resources.bufferProviders
        indexBuffer = setup.resources.indexBuffer
        self.textures = setup.resources.textures
        self.curveTies = setup.animationState.curveTies
        self.postures = setup.animationState.postures
        counter = setup.animationState.counter
        solver = setup.animationState.solver
    }

    private static func makeSetup(device: MTLDevice, pmx: PMX, vmd: VMD) -> PMXObjectSetup {
        return PMXObjectSetup(
            resources: Self.makeResources(device: device, pmx: pmx),
            animationState: Self.makeAnimationState(pmx: pmx, vmd: vmd))
    }

    /// 1 frame 分のアニメーション、物理、morph、GPU 転送をまとめて進める。
    /// 呼び出し側は draw 前に毎フレームこれを実行する前提。
    func calc(_ renderer: Renderer) {
        let session = makeFramePipelineSession(renderer)
        updateFrame(session)
    }

    private func currentFrameContext(_ renderer: Renderer) -> PMXFrameContext {
        return PMXFrameContext(
            animation: PMXAnimationContext(tick: currentAnimationTick()),
            render: PMXRenderContext(
                renderer: renderer,
                transforms: PMXModelTransforms(
                    modelMatrix: modelMatrix,
                    normalMatrix: normalMatrix)))
    }

    private func currentAnimationTick() -> PMXAnimationTick {
        return PMXAnimationTick(
            frameNumber: counter.currentFrame(),
            maxIterations: counter.maxIt())
    }

    private func updateFrame(_ session: PMXFramePipelineSession) {
        updateAnimationState(makeAnimationUpdateSession(session.update.animation))
        updateGeometryState(makeGeometryUpdateSession(session.update.geometry))
        updateRenderBuffers(session.update.render)
    }

    private func makeFrameUpdateSession(_ context: PMXFrameContext) -> PMXFrameUpdateSession {
        return PMXFrameUpdateSession(
            animation: currentAnimationUpdateContext(context),
            geometry: currentGeometryUpdateContext(context),
            render: currentRenderUpdateContext(context))
    }

    private func makeFramePipelineSession(_ renderer: Renderer) -> PMXFramePipelineSession {
        let context = currentFrameContext(renderer)
        return PMXFramePipelineSession(
            context: context,
            update: makeFrameUpdateSession(context))
    }

    private func updateAnimationState(_ session: PMXAnimationUpdateSession) {
        updatePosturesForCurrentFrame(tick: session.context.animation.tick)
        runPhysicsStep()
    }

    private func currentAnimationUpdateContext(_ context: PMXFrameContext) -> PMXAnimationUpdateContext {
        return PMXAnimationUpdateContext(animation: context.animation)
    }

    private func makeAnimationUpdateSession(_ context: PMXAnimationUpdateContext) -> PMXAnimationUpdateSession {
        return PMXAnimationUpdateSession(context: context)
    }

    private func updateGeometryState(_ session: PMXGeometryUpdateSession) {
        prepareVertexBufferForCurrentFrame(session.context.geometry)
    }

    private func currentGeometryUpdateContext(_ context: PMXFrameContext) -> PMXGeometryUpdateContext {
        return PMXGeometryUpdateContext(
            geometry: currentGeometryContext(tick: context.animation.tick))
    }

    private func makeGeometryUpdateSession(_ context: PMXGeometryUpdateContext) -> PMXGeometryUpdateSession {
        return PMXGeometryUpdateSession(context: context)
    }

    private func currentGeometryContext(tick: PMXAnimationTick) -> PMXGeometryContext {
        return PMXGeometryContext(
            tick: tick,
            vertexBuffer: makeCurrentVertexBuffer())
    }

    /// FK / IK / Grant 解決後に、全ボーンの world matrix を現在フレームへ揃える。
    /// 物理はこの結果を入力として受け取るため、姿勢計算のまとまりをここで固定する。
    private func updatePosturesForCurrentFrame(tick: PMXAnimationTick) {
        FKSolver(postures, curveTies: self.curveTies, frameNum: tick.frameNumber)
        IKSolver(postures, maxIt: tick.maxIterations)
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

    private static func makeAnimationState(pmx: PMX, vmd: VMD) -> PMXObjectAnimationState {
        return PMXObjectAnimationState(
            curveTies: Self.makeCurveTies(pmx: pmx, vmd: vmd),
            postures: Self.makePostures(for: pmx.bones),
            counter: Self.makeAnimationCounter(vmd: vmd),
            solver: Self.makePhysicsSolver(pmx: pmx)
        )
    }

    private static func makeAnimationCounter(vmd: VMD) -> AnimationCounter {
        return NormalCounter(beginFrameNum: 0, endFrameNum: vmd.meta.frameCount)
        // return DebugCounter(beginFrameNum: 160, endFrameNum: vmd.frameCount)
    }

    private static func makeResources(device: MTLDevice, pmx: PMX) -> PMXObjectResources {
        let vertexData = PMXVertex2NSData(pmx.vertices)!
        return PMXObjectResources(
            vertexData: vertexData,
            bufferProviders: Self.makeBufferProviders(device: device, vertexData: vertexData, boneCount: pmx.bones.count, materialCount: pmx.materials.count),
            indexBuffer: Self.makeIndexBuffer(device: device, indices: pmx.indices),
            textures: Self.loadTextures(device: device, texturePaths: pmx.texturePaths)
        )
    }

    private static func makeIndexBuffer(device: MTLDevice, indices: [UInt16]) -> MTLBuffer {
        return device.makeBuffer(
            bytes: indices,
            length: indices.count * MemoryLayout<UInt16>.size,
            options: MTLResourceOptions()
        )!
    }

    private static func makeBufferProviders(device: MTLDevice,
                                            vertexData: Data,
                                            boneCount: Int,
                                            materialCount: Int) -> PMXBufferProviders {
        return PMXBufferProviders(
            vertex: BufferProvider(
                device: device,
                inflightBuffersCount: 3,
                data: vertexData),
            uniforms: BufferProvider(
                device: device,
                inflightBuffersCount: 3,
                sizeOfUniformsBuffer: MemoryLayout<ShaderUniforms>.stride),
            matrixPalette: BufferProvider(
                device: device,
                inflightBuffersCount: 3,
                sizeOfUniformsBuffer: MemoryLayout<float4x4>.size * 4 * boneCount),
            materials: BufferProvider(
                device: device,
                inflightBuffersCount: 3,
                sizeOfUniformsBuffer: MemoryLayout<ShaderMaterial>.stride * materialCount))
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

    private static func makePhysicsSolver(pmx: PMX) -> PhysicsSolving {
        return PhysicsSolverMake(pmx)
    }

    /// ベース頂点を inflight buffer へコピーし、現在フレームの morph を上書き適用する。
    /// CPU morph 実装の責務を `calc` 本体から切り離し、将来の GPU 化や計測をしやすくする。
    private func prepareVertexBufferForCurrentFrame(_ context: PMXGeometryContext) {
        currentVertexBuffer = context.vertexBuffer
        copyBaseVertexData(into: context.vertexBuffer)
        applyMorph(tick: context.tick)
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

    /// 左右いずれかの morph key 群から、実際に適用すべき morph と重みの組だけを解決する。
    /// CPU 頂点更新は別段に残し、VMD / PMX の名前解決だけをここへ閉じ込める。
    private func resolveMorphUpdates(_ morphs: [VMDMorph], weightScale: Float) -> [MorphUpdate] {
        var updates: [MorphUpdate] = []
        for vm in morphs {
            guard let pm = morph(named: vm.name) else {
                continue
            }

            switch pm.type {
            case .vertex:
                updates.append(MorphUpdate(morph: pm, weight: vm.weight * weightScale))
            case .group:
                break
            case .bone:
                break
            default:
                break
            }
        }
        return updates
    }

    private func resolveMorphUpdatesIfPresent(_ morphs: [VMDMorph]?, weightScale: Float) -> [MorphUpdate] {
        guard let morphs else {
            return []
        }
        return resolveMorphUpdates(morphs, weightScale: weightScale)
    }

    /// morph 名解決済みの更新だけを現在の頂点 buffer へ適用する。
    /// 将来 GPU morph 化するなら、この適用段を差し替える想定。
    private func applyMorphUpdates(_ updates: [MorphUpdate]) {
        for update in updates {
            updateVertex(update.morph, update.weight)
        }
    }

    private func applyMorph(tick: PMXAnimationTick) {
        guard let session = makeMorphPipelineSession(tick: tick) else {
            return
        }

        applyMorphUpdates(session.application.updates)
    }

    private func currentMorphApplicationContext(tick: PMXAnimationTick) -> PMXMorphApplicationContext? {
        guard let frame = currentMorphFrameContext(tick: tick) else {
            return nil
        }

        return PMXMorphApplicationContext(frame: frame)
    }

    private func makeMorphResolutionSession(_ context: PMXMorphApplicationContext) -> PMXMorphResolutionSession {
        return PMXMorphResolutionSession(
            updates: makeMorphFrameResolutionSession(context.frame).updates)
    }

    private func makeMorphFrameResolutionSession(_ frame: PMXMorphFrameContext) -> PMXMorphFrameResolutionSession {
        return PMXMorphFrameResolutionSession(
            frame: frame,
            updates: resolveMorphUpdates(frame))
    }

    private func makeMorphApplicationSession(_ context: PMXMorphApplicationContext) -> PMXMorphApplicationSession {
        let resolution = makeMorphResolutionSession(context)
        return PMXMorphApplicationSession(updates: resolution.updates.left + resolution.updates.right)
    }

    private func makeMorphPipelineSession(tick: PMXAnimationTick) -> PMXMorphPipelineSession? {
        guard let context = currentMorphApplicationContext(tick: tick) else {
            return nil
        }

        return PMXMorphPipelineSession(
            application: makeMorphApplicationSession(context))
    }

    private func resolveMorphUpdates(_ context: PMXMorphFrameContext) -> PMXMorphUpdates {
        return PMXMorphUpdates(
            left: resolveMorphUpdatesIfPresent(context.frames.left, weightScale: context.weights.left),
            right: resolveMorphUpdatesIfPresent(context.frames.right, weightScale: context.weights.right))
    }

    private func currentMorphFrameContext(tick: PMXAnimationTick) -> PMXMorphFrameContext? {
        let frames = currentMorphKeyFrames(tick: tick)
        guard hasMorphKeyFrames(frames) else {
            return nil
        }

        return PMXMorphFrameContext(
            frames: frames,
            weights: morphFrameWeights(tick: tick, leftMorphs: frames.left, rightMorphs: frames.right))
    }

    private func hasMorphKeyFrames(_ keyFrames: MorphKeyFramePair) -> Bool {
        return keyFrames.left != nil || keyFrames.right != nil
    }

    private func morph(named name: String) -> Morph? {
        return pmx.morphs[name]
    }

    /// 現在フレームの左右 keyframe 群をまとめて取り出す。
    /// `VMD` の返り値形式に `PMXObject` 全体を強く依存させないための薄い境界として扱う。
    private func currentMorphKeyFrames(tick: PMXAnimationTick) -> MorphKeyFramePair {
        let morphs = vmd.getMorph(tick.frameNumber)
        return MorphKeyFramePair(left: morphs.left, right: morphs.right)
    }

    /// 左右 keyframe の時刻差から、現在フレームで適用する morph の寄与率を求める。
    /// morph 適用本体から補間重み計算を分離して、将来のテスト追加点を見つけやすくする。
    private func morphFrameWeights(tick: PMXAnimationTick, leftMorphs: [VMDMorph]?, rightMorphs: [VMDMorph]?) -> MorphFrameWeights {
        let currentFrame = tick.frameNumber
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
    private func makeFrameRenderBufferAssembly(_ context: PMXRenderUpdateContext) -> PMXFrameRenderBufferAssembly {
        let components = makeRenderBufferComponentSession(context.render)
        return PMXFrameRenderBufferAssembly(
            buffers: PMXFrameRenderBuffers(
                uniforms: components.uniforms,
                matrixPalette: components.matrixPalette,
                materials: components.materials))
    }

    /// 現在フレームの draw が参照する uniform / palette / material buffer を更新する。
    private func updateRenderBuffers(_ context: PMXRenderUpdateContext) {
        let session = makeRenderBufferUpdateSession(context)
        storeRenderBuffers(makeRenderBufferApplySession(session).buffers)
    }

    private func currentRenderUpdateContext(_ context: PMXFrameContext) -> PMXRenderUpdateContext {
        return PMXRenderUpdateContext(render: context.render)
    }

    private func makeRenderBufferUpdateSession(_ context: PMXRenderUpdateContext) -> PMXRenderBufferUpdateSession {
        return PMXRenderBufferUpdateSession(
            assembly: makeFrameRenderBufferAssembly(context))
    }

    private func makeRenderBufferApplySession(_ session: PMXRenderBufferUpdateSession) -> PMXRenderBufferApplySession {
        return PMXRenderBufferApplySession(buffers: session.assembly.buffers)
    }

    private func makeRenderBufferComponentSession(_ context: PMXRenderContext) -> PMXRenderBufferComponentSession {
        return PMXRenderBufferComponentSession(
            uniforms: makeUniformBuffer(context),
            matrixPalette: makeMatrixPaletteBufferSession().buffer,
            materials: makeMaterialBufferSession().buffer)
    }

    private func withNextBuffer(_ provider: BufferProvider) -> MTLBuffer {
        return provider.nextBuffer()
    }

    private func storeRenderBuffers(_ renderBuffers: PMXFrameRenderBuffers) {
        applyStoredRenderBuffers(makeRenderBufferStorageApplySession(renderBuffers).storage)
    }

    private func makeRenderBufferStorageSession(_ renderBuffers: PMXFrameRenderBuffers) -> PMXRenderBufferStorageSession {
        return PMXRenderBufferStorageSession(
            buffers: PMXStoredRenderBuffers(
                uniformBuffer: renderBuffers.uniforms,
                matrixPalette: renderBuffers.matrixPalette,
                materialBuffer: renderBuffers.materials))
    }

    private func makeRenderBufferStorageApplySession(_ renderBuffers: PMXFrameRenderBuffers) -> PMXRenderBufferStorageApplySession {
        return PMXRenderBufferStorageApplySession(
            storage: makeRenderBufferStorageSession(renderBuffers).buffers)
    }

    private func applyStoredRenderBuffers(_ buffers: PMXStoredRenderBuffers) {
        uniformBuffer = buffers.uniformBuffer
        matrixPalette = buffers.matrixPalette
        materialBuffer = buffers.materialBuffer
    }

    /// 描画に必要な camera / shadow 行列をまとめて uniform buffer へ転送する。
    /// shadowMatrixGB は Metal のテクスチャ座標系に合わせて Y 反転込みで作っている。
    private func makeUniformBuffer(_ context: PMXRenderContext) -> MTLBuffer {
        let session = makeUniformBufferSession(context)

        CopyMatrices(
            session.buffer,
            context.transforms.modelMatrix,
            session.renderMatrices.modelViewMatrix,
            context.renderer.projectionMatrix,
            context.transforms.normalMatrix,
            session.renderMatrices.shadowMatrix,
            session.renderMatrices.shadowMatrixGB)

        return session.buffer
    }

    private func makeUniformBufferSession(_ context: PMXRenderContext) -> PMXUniformBufferSession {
        // "Metal Shading Language Guide" says:
        // In Metal, the origin of the pixel coordinate system of a texture is
        // defined at the top-left corner.
        //
        // So shadowMatrixGB's Y scale value is negative.
        //
        // see https://goo.gl/vgIYTf
        return PMXUniformBufferSession(
            buffer: withNextBuffer(bufferProviders.uniforms),
            renderMatrices: PMXRenderDataEncoder.makeRenderMatrices(
                context.renderer,
                context.transforms.modelMatrix))
    }

    /// 各ボーンの world matrix を matrix palette buffer へ詰める。
    /// shader 側の skinning はこの palette を前提にしている。
    private func makeMatrixPaletteBufferSession() -> PMXMatrixPaletteBufferSession {
        let palette = withNextBuffer(bufferProviders.matrixPalette)
        PMXRenderDataEncoder.writeMatrixPalette(palette, postures)

        return PMXMatrixPaletteBufferSession(buffer: palette)
    }

    /// material ごとの色パラメータを shader 用の連続領域へ詰める。
    /// texture index や sphere map などは別経路で扱うため、ここでは色だけ送る。
    private func makeMaterialBufferSession() -> PMXMaterialBufferSession {
        let materialBuffer = withNextBuffer(bufferProviders.materials)
        PMXRenderDataEncoder.writeMaterials(materialBuffer, pmx.materials)

        return PMXMaterialBufferSession(buffer: materialBuffer)
    }

    private func makeCurrentVertexBuffer() -> MTLBuffer {
        return withNextBuffer(bufferProviders.vertex)
    }

    private func copyBaseVertexData(into buffer: MTLBuffer) {
        memcpy(buffer.contents(), (vertexData as NSData).bytes, vertexData.count)
    }
}
