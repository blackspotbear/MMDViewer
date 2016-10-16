import Foundation
import GLKit

private func LoadPMXMeta(_ pmx: PMX, _ reader: DataReader) {
    let pmxStr = "PMX " as NSString
    for i in 0 ..< pmxStr.length {
        let c: UInt8 = reader.read()
        if unichar(c) != pmxStr.character(at: i) {
            // TODO: impl
        }
    }

    pmx.meta.format = pmxStr as String
    pmx.meta.version = reader.read()

    var remain = reader.readIntN(1)
    pmx.meta.encoding           = remain > 0 ? reader.readIntN(1) : 0; remain -= 1
    pmx.meta.additionalUVCount  = remain > 0 ? reader.readIntN(1) : 0; remain -= 1
    pmx.meta.vertexIndexSize    = remain > 0 ? reader.readIntN(1) : 0; remain -= 1
    pmx.meta.textureIndexSize   = remain > 0 ? reader.readIntN(1) : 0; remain -= 1
    pmx.meta.materialIndexSize  = remain > 0 ? reader.readIntN(1) : 0; remain -= 1
    pmx.meta.boneIndexSize      = remain > 0 ? reader.readIntN(1) : 0; remain -= 1
    pmx.meta.morphIndexSize     = remain > 0 ? reader.readIntN(1) : 0; remain -= 1
    pmx.meta.rigidBodyIndexSize = remain > 0 ? reader.readIntN(1) : 0; remain -= 1

    if remain > 0 {
        reader.skip(remain)
    }

    pmx.meta.modelName = reader.readString()!
    pmx.meta.modelNameE = reader.readString()!
    pmx.meta.comment = reader.readString()!
    pmx.meta.commentE = reader.readString()!

    pmx.meta.vertexCount = reader.readIntN(4)
}

private func LoadPMXVertices(_ pmx: PMX, _ reader: DataReader) {
    for _ in 0 ..< pmx.meta.vertexCount {
        let v = GLKVector3Make(reader.read(), reader.read(), -reader.read())
        let n = GLKVector3Make(reader.read(), reader.read(), -reader.read())
        let uv = UV(reader.read(), reader.read())
        let skinningMethod: UInt8 = reader.read()

        var euvs: [GLKVector4] = []
        for _ in 0 ..< pmx.meta.additionalUVCount {
            let euv = GLKVector4Make(reader.read(), reader.read(), reader.read(), reader.read())
            euvs.append(euv)
        }

        var boneIndices: [UInt16] = []
        var boneWeights: [Float] = []
        if skinningMethod == 0 {
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(0)
            boneIndices.append(0)
            boneIndices.append(0)
            boneWeights.append(1)
            boneWeights.append(0)
            boneWeights.append(0)
            boneWeights.append(0)
        } else if skinningMethod == 1 {
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(0)
            boneIndices.append(0)
            boneWeights.append(reader.read())
            boneWeights.append(1 - boneWeights.last!)
            boneWeights.append(0)
            boneWeights.append(0)
        } else if skinningMethod == 2 {
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneWeights.append(reader.read())
            boneWeights.append(reader.read())
            boneWeights.append(reader.read())
            boneWeights.append(reader.read())
        } else if skinningMethod == 3 {
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(UInt16(reader.readIntN(pmx.meta.boneIndexSize)))
            boneIndices.append(0)
            boneIndices.append(0)
            boneWeights.append(reader.read())
            boneWeights.append(1 - boneWeights.last!)
            boneWeights.append(0)
            boneWeights.append(0)

            reader.skip(MemoryLayout<Float>.size * 3 * 3)
        } else {
            fatalError("not implemented")
        }

        let vertex = PMXVertex(
            v: v,
            n: n,
            uv: uv,
            euvs: euvs,
            skinningMethod: skinningMethod,
            boneWeights: boneWeights,
            boneIndices: boneIndices)

        // edge magnification
        let _: Float = reader.read() // not supported at this time

        pmx.vertices.append(vertex)
    }
}

private func LoadPMXFaces(_ pmx: PMX, _ reader: DataReader) {
    let faceCount: Int32 = reader.read()
    for _ in 0 ..< faceCount / 3 {
        let index0 = UInt16(reader.readIntN(pmx.meta.vertexIndexSize))
        let index1 = UInt16(reader.readIntN(pmx.meta.vertexIndexSize))
        let index2 = UInt16(reader.readIntN(pmx.meta.vertexIndexSize))
        pmx.indices.append(index0)
        pmx.indices.append(index2)
        pmx.indices.append(index1)
    }
}

private func LoadPMXTexturePaths(_ pmx: PMX, _ reader: DataReader) {
    let textureCount: Int32 = reader.read()
    for _ in 0 ..< textureCount {
        pmx.texturePaths.append(reader.readString()!)
    }
}

private func LoadPMXMaterials(_ pmx: PMX, _ reader: DataReader) {
    let materialCount = reader.readIntN(4)

    for _ in 0 ..< materialCount {
        let name = reader.readString()
        let nameE = reader.readString()
        let diffuse = Color(reader.read(), reader.read(), reader.read(), reader.read())
        let specular = Color(reader.read(), reader.read(), reader.read(), 1.0)
        let specularPower: Float = reader.read()
        let ambient  = Color(reader.read(), reader.read(), reader.read(), 1.0)
        let flag: MaterialFlag = reader.read()
        let edgeColor = Color(reader.read(), reader.read(), reader.read(), reader.read())
        let edgeSize: Float = reader.read()
        let textureIndex: Int = reader.readIntN(pmx.meta.textureIndexSize)
        let sphereTextureIndex: Int = reader.readIntN(pmx.meta.textureIndexSize)
        let sphereMode: UInt8 = reader.read()
        let sharedToon: Bool = reader.read()
        let toonTextureIndex = sharedToon ? reader.readIntN(1) : reader.readIntN(pmx.meta.textureIndexSize)
        let memo = reader.readString()!
        let vertexCount: Int32 = reader.read()

        let material = Material(
            name: name!,
            nameE: nameE!,

            diffuse: diffuse,
            specular: specular,
            specularPower: specularPower,
            ambient: ambient,

            flag: flag,
            edgeColor: edgeColor,
            edgeSize: edgeSize,

            textureIndex: textureIndex,
            sphereTextureIndex: sphereTextureIndex,
            sphereMode: sphereMode,

            sharedToon: sharedToon,
            toonTextureIndex: toonTextureIndex,

            memo: memo,
            vertexCount: vertexCount
        )

        pmx.materials.append(material)
    }
}

private func LoadPMXBones(_ pmx: PMX, _ reader: DataReader) {
    let boneCount = reader.readIntN(4)

    for _ in 0 ..< boneCount {
        let boneName = reader.readString()
        let boneNameE = reader.readString()
        let pos = GLKVector3Make(reader.read(), reader.read(), -reader.read())
        let parentBoneIndex = reader.readIntN(pmx.meta.boneIndexSize)
        let deformLayer: Int32 = reader.read()
        let bitFlag = BoneFlag(rawValue: reader.read())

        var childPos = GLKVector3Make(0, 0, 0)
        var childBoneIndex = 0
        if bitFlag.contains(.ParentBoneIndex) {
            childBoneIndex = reader.readIntN(pmx.meta.boneIndexSize)
        } else {
            childPos = GLKVector3Make(reader.read(), reader.read(), -reader.read())
        }

        let adding = bitFlag.isDisjoint(with: [.RotationAdd, .TranslationAdd]) == false
        let affectingParentBoneIndex = adding ? reader.readIntN(pmx.meta.boneIndexSize) : 0
        let affectingRate: Float = adding ? reader.read() : 0
        let fixAxis = bitFlag.contains(.FixAxis) ? GLKVector3Make(reader.read(), reader.read(), -reader.read()) : GLKVector3Make(0, 0, 0)

        var xAxis = GLKVector3Make(0, 0, 0)
        var zAxis = GLKVector3Make(0, 0, 0)
        if bitFlag.contains(.LocalAxis) {
            xAxis = GLKVector3Make(reader.read(), reader.read(), -reader.read())
            zAxis = GLKVector3Make(reader.read(), reader.read(), -reader.read())
        }

        let key: Int32 = bitFlag.contains(.DeformExternalParent) ? reader.read() : 0

        var ikLinks: [IKLink] = []
        var ikTargetBoneIndex: Int = 0
        var ikLoopCount: Int32 = 0
        var ikAngularLimit: Float = 0
        if bitFlag.contains(.InverseKinematics) {
            ikTargetBoneIndex = reader.readIntN(pmx.meta.boneIndexSize)
            ikLoopCount = reader.read()
            ikAngularLimit = reader.read()
            let ikLinkCount: Int32 = reader.read()

            for _ in 0 ..< ikLinkCount {
                let boneIndex = reader.readIntN(pmx.meta.boneIndexSize)
                let angularLimit = reader.read() as UInt8 != 0
                let angularLimitMin = angularLimit ? GLKVector3Make(reader.read(), reader.read(), reader.read()) : GLKVector3Make(0, 0, 0)
                let angularLimitMax = angularLimit ? GLKVector3Make(reader.read(), reader.read(), reader.read()) : GLKVector3Make(0, 0, 0)

                let ikLink = IKLink(
                    boneIndex: boneIndex,
                    angularLimit: angularLimit,
                    angularLimitMin: angularLimitMin,
                    angularLimitMax: angularLimitMax
                )
                ikLinks.append(ikLink)
            }
        }

        let bone = Bone(
            name: boneName!,
            nameE: boneNameE!,
            pos: pos,
            parentBoneIndex: parentBoneIndex,
            deformLayer: deformLayer,
            bitFlag: bitFlag,
            childOffset: childPos,
            childBoneIndex: childBoneIndex,
            affectingParentBoneIndex: affectingParentBoneIndex,
            affectingRate: affectingRate,
            fixAxis: fixAxis,
            xAxis: xAxis,
            zAxis: zAxis,
            key: key,
            ikTargetBoneIndex: ikTargetBoneIndex,
            ikLoopCount: ikLoopCount,
            ikAngularLimit: ikAngularLimit,
            ikLinks: ikLinks)

        pmx.bones.append(bone)
    }

}

private func LoadPMXMorphElement(_ type: MorphType, _ pmx: PMX, _ reader: DataReader) -> Any {
    switch type {
    case .group:
        return MorphGroup(index: reader.readIntN(pmx.meta.morphIndexSize), ratio: reader.read())
    case .vertex:
        return MorphVertex(index: reader.readIntN(pmx.meta.vertexIndexSize),
                           trans: GLKVector3Make(reader.read(), reader.read(), -reader.read()))
    case .bone:
        return MorphBone(index: reader.readIntN(pmx.meta.boneIndexSize),
                         trans: GLKVector3Make(reader.read(), reader.read(), -reader.read()),
                         rot: GLKQuaternionMake(reader.read(), reader.read(), reader.read(), reader.read()))
    case .uv: fallthrough
    case .uv1: fallthrough
    case .uv2: fallthrough
    case .uv3: fallthrough
    case .uv4:
        return MorphUV(index: reader.readIntN(pmx.meta.vertexIndexSize),
                       trans: GLKVector4Make(reader.read(), reader.read(), reader.read(), reader.read()))
    case .material:
        return MorphMaterial(index: reader.readIntN(pmx.meta.materialIndexSize),
                             opType: reader.read(),
                             diffuse: GLKVector4Make(reader.read(), reader.read(), reader.read(), reader.read()),
                             specular: GLKVector3Make(reader.read(), reader.read(), reader.read()),
                             shininess: reader.read(),
                             ambient: GLKVector3Make(reader.read(), reader.read(), reader.read()),
                             edgeColor: GLKVector4Make(reader.read(), reader.read(), reader.read(), reader.read()),
                             edgeSize: reader.read(),
                             textureColor: GLKVector4Make(reader.read(), reader.read(), reader.read(), reader.read()),
                             sphereTextureColor: GLKVector4Make(reader.read(), reader.read(), reader.read(), reader.read()),
                             toonTextureColor: GLKVector4Make(reader.read(), reader.read(), reader.read(), reader.read()))
    }
}

private func LoadPMXMorphs(_ pmx: PMX, _ reader: DataReader) {
    let morphCount = reader.readIntN(4)

    for _ in 0 ..< morphCount {
        var m = Morph(name: reader.readString()!, nameE: reader.readString()!, panel: reader.readIntN(1), type: MorphType(rawValue: reader.readIntN(1))!, elements: [])
        let elementCount = reader.readIntN(4)

        for _ in 0 ..< elementCount {
            m.elements.append(LoadPMXMorphElement(m.type, pmx, reader))
        }

        pmx.morphs[m.name] = m
    }
}

private func Skip(_ pmx: PMX, _ reader: DataReader) {
    let rigidCount = reader.readIntN(4)

    for _ in 0 ..< rigidCount {
        _ = reader.readString()
        _ = reader.readString()
        _ = reader.read() as UInt8
        let n = reader.readIntN(4)
        for _ in 0 ..< n {
            if reader.read() as UInt8 == 0 {
                _ = reader.readIntN(pmx.meta.boneIndexSize)
            } else {
                _ = reader.readIntN(pmx.meta.morphIndexSize)
            }
        }
    }
}

private func LoadRigidBodies(_ pmx: PMX, _ reader: DataReader) {
    let rigidCount = reader.readIntN(4)

    for _ in 0 ..< rigidCount {
        let rigidBody = RigidBody(name: reader.readString()!, nameE: reader.readString()!, boneIndex: reader.readIntN(pmx.meta.boneIndexSize), groupID: reader.read(), groupFlag: reader.read(), shapeType: reader.read(), size: GLKVector3Make(reader.read(), reader.read(), reader.read()), pos: GLKVector3Make(reader.read(), reader.read(), -reader.read()), rot: GLKVector3Make(reader.read(), reader.read(), reader.read()), mass: reader.read(), linearDamping: reader.read(), angularDamping: reader.read(), restitution: reader.read(), friction: reader.read(), type: reader.read())
        pmx.rigidBodies.append(rigidBody)
    }
}

private func LoadConstraints(_ pmx: PMX, _ reader: DataReader) {
    let constraintCount = reader.readIntN(4)

    for _ in 0 ..< constraintCount {
        let constraint = Constraint(name: reader.readString()!, nameE: reader.readString()!, type: reader.read(), rigidAIndex: reader.readIntN(pmx.meta.rigidBodyIndexSize), rigidBIndex: reader.readIntN(pmx.meta.rigidBodyIndexSize), pos: GLKVector3Make(reader.read(), reader.read(), -reader.read()), rot: GLKVector3Make(reader.read(), reader.read(), reader.read()), linearLowerLimit: GLKVector3Make(reader.read(), reader.read(), reader.read()), linearUpperLimit: GLKVector3Make(reader.read(), reader.read(), reader.read()), angularLowerLimit: GLKVector3Make(reader.read(), reader.read(), reader.read()), angularUpperLimit: GLKVector3Make(reader.read(), reader.read(), reader.read()), linearSpringStiffness: GLKVector3Make(reader.read(), reader.read(), reader.read()), angularSpringStiffness: GLKVector3Make(reader.read(), reader.read(), reader.read()))
        pmx.constraints.append(constraint)
    }
}

class PMX {
    var meta = PMXMeta()
    var vertices: [PMXVertex] = []
    var indices: [UInt16] = []
    var texturePaths: [String] = []
    var materials: [Material] = []
    var bones: [Bone] = []
    var morphs: [String:Morph] = [:]
    var rigidBodies: [RigidBody] = []
    var constraints: [Constraint] = []

    init(data: Data) {
        let reader = DataReader(data: data)

        LoadPMXMeta(self, reader)
        LoadPMXVertices(self, reader)
        LoadPMXFaces(self, reader)
        LoadPMXTexturePaths(self, reader)
        LoadPMXMaterials(self, reader)
        LoadPMXBones(self, reader)
        LoadPMXMorphs(self, reader)
        Skip(self, reader)
        LoadRigidBodies(self, reader)
        LoadConstraints(self, reader)
    }
}
