import Foundation
import GLKit
import Metal

struct BoneAttr {
    static let TX = 0
    static let TY = 1
    static let TZ = 2
    static let QX = 3
    static let QY = 4
    static let QZ = 5
    static let QW = 6

    static var count: Int { return QW + 1 }
}

struct BezierSegment {
    var value: Float = 0.0
    var controlPoint = [GLKVector2](repeating: GLKVector2Make(0, 0), count: 2)
}

struct KeyFrame {
    var frameNum: Int
    var segments = [BezierSegment](repeating: BezierSegment(), count: BoneAttr.count)
    var noTranslate: Bool {
        return
            segments[BoneAttr.TX].value == 0 &&
                segments[BoneAttr.TY].value == 0 &&
                segments[BoneAttr.TZ].value == 0
    }
    var noQuaternion: Bool {
        return
            segments[BoneAttr.QX].value == 0 &&
                segments[BoneAttr.QY].value == 0 &&
                segments[BoneAttr.QZ].value == 0 &&
                segments[BoneAttr.QW].value == 0
    }

    init(_ frameNum: Int) {
        self.frameNum = frameNum
    }
}

class CurveTie {
    var boneName = ""
    var keys: [KeyFrame] = []
}

struct VMDMeta {
    var totalFrameCount = 0
    var content = ""
    var modelName = ""
    var frameCount = 0
}

struct VMDMorph {
    var name = ""
    var frameNum = 0
    var weight: Float = 0
}

private func InterpolateKeyFrameValue(_ k1: KeyFrame, _ k2: KeyFrame, _ frameNum: Int) -> (GLKQuaternion?, GLKVector3?) {
    let t = Float(frameNum - k1.frameNum) / Float(k2.frameNum - k1.frameNum)
    let pos: GLKVector3? = k1.noTranslate ? nil : InterpolatePos(k1, k2, t)
    let rot: GLKQuaternion? = k1.noQuaternion ? nil : InterpolateRot(k1, k2, t)
    return (rot, pos)
}

private func GetKeyFrameValue(_ key: KeyFrame) -> (GLKQuaternion?, GLKVector3?) {
    let pos: GLKVector3? = key.noTranslate ? nil : GLKVector3Make(
        key.segments[BoneAttr.TX].value,
        key.segments[BoneAttr.TY].value,
        key.segments[BoneAttr.TZ].value)
    let rot: GLKQuaternion? = key.noQuaternion ? nil : GLKQuaternionMake(
        key.segments[BoneAttr.QX].value,
        key.segments[BoneAttr.QY].value,
        key.segments[BoneAttr.QZ].value,
        key.segments[BoneAttr.QW].value)
    return (rot, pos)
}

func GetCurveValue(_ tie: CurveTie, frameNum: Int) -> (GLKQuaternion?, GLKVector3?) {
    if tie.keys.count == 0 {
        return (nil, nil)
    }

    var left = 0
    var right = tie.keys.count - 1
    let keys = tie.keys

    while true {
        let index = (right - left) / 2 + left
        let key = keys[index]

        if key.frameNum == frameNum {
            return GetKeyFrameValue(key)
        } else if key.frameNum < frameNum {
            if left == index {
                return InterpolateKeyFrameValue(key, keys[right], frameNum)
            } else {
                left = index
            }
        } else {
            if right == index {
                return InterpolateKeyFrameValue(keys[left], key, frameNum)
            } else {
                right = index
            }
        }
    }
}

class VMD {
    var meta = VMDMeta()
    var curveTies: [String: CurveTie] = [:]
    var morphKeyFrames: [Int:[VMDMorph]] = [:]

    func getTransformation(_ boneName: String, frameNum: Int) -> (GLKQuaternion?, GLKVector3?) {
        if let tie = curveTies[boneName] {
            return GetCurveValue(tie, frameNum: frameNum)
        }
        return (nil, nil)
    }

    private func getLeft(_ frameNum: Int) -> [VMDMorph]? {
        for f in (0...frameNum).reversed() {
            if let m = self.morphKeyFrames[f] {
                return m
            }
        }
        return nil
    }

    private func getRight(_ frameNum: Int) -> [VMDMorph]? {
        for f in frameNum...meta.frameCount {
            if let m = self.morphKeyFrames[f] {
                return m
            }
        }
        return nil
    }

    func getMorph(_ frameNum: Int) -> (left: [VMDMorph]?, right: [VMDMorph]?) {
        return (getLeft(frameNum), getRight(frameNum))
    }

    init(data: Data) {
        let reader = DataReader(data: data)
        LoadVMDMeta(self, reader)
        LoadVMDMotion(self, reader)
        LoadVMDMorph(self, reader)
    }
}

private func InterpolateBezier(_ p2: GLKVector2, _ p3: GLKVector2, _ t: Float) -> GLKVector2 {
    // t1 = 0, t4 = 127
    let tt = t * t
    let ttt127 = tt * t * 127
    let u = 1 - t
    let ttu3 = tt * u * 3
    let tuu3 = t * u * u

    return GLKVector2Make(
        ttt127 + ttu3 * p3.x + tuu3 * p2.x,
        ttt127 + ttu3 * p3.y + tuu3 * p2.y
    )

}

private func InterpolatePos(_ left: KeyFrame, _ right: KeyFrame, _ t: Float) -> GLKVector3 {
    let tx = InterpolateBezier(
            left.segments[BoneAttr.TX].controlPoint[0],
            left.segments[BoneAttr.TX].controlPoint[1],
            t)
    let ty = InterpolateBezier(
            left.segments[BoneAttr.TY].controlPoint[0],
            left.segments[BoneAttr.TY].controlPoint[1],
            t)
    let tz = InterpolateBezier(
            left.segments[BoneAttr.TZ].controlPoint[0],
            left.segments[BoneAttr.TZ].controlPoint[1],
            t)

    let x = (right.segments[BoneAttr.TX].value - left.segments[BoneAttr.TX].value) * tx.y / 127 + left.segments[BoneAttr.TX].value
    let y = (right.segments[BoneAttr.TY].value - left.segments[BoneAttr.TY].value) * ty.y / 127 + left.segments[BoneAttr.TY].value
    let z = (right.segments[BoneAttr.TZ].value - left.segments[BoneAttr.TZ].value) * tz.y / 127 + left.segments[BoneAttr.TZ].value

    return GLKVector3Make(x, y, z)
}

private func InterpolateRot(_ left: KeyFrame, _ right: KeyFrame, _ t: Float) -> GLKQuaternion {
    let qw = InterpolateBezier(
            left.segments[BoneAttr.QW].controlPoint[0],
            left.segments[BoneAttr.QW].controlPoint[1],
            t)

    let q1 = GLKQuaternionMake(
        left.segments[BoneAttr.QX].value,
        left.segments[BoneAttr.QY].value,
        left.segments[BoneAttr.QZ].value,
        left.segments[BoneAttr.QW].value
    )
    let q2 = GLKQuaternionMake(
        right.segments[BoneAttr.QX].value,
        right.segments[BoneAttr.QY].value,
        right.segments[BoneAttr.QZ].value,
        right.segments[BoneAttr.QW].value
    )
    return GLKQuaternionSlerp(q1, q2, qw.y / 127) // ??
}

private func LoadVMDMeta(_ vmd: VMD, _ reader: DataReader) {
    vmd.meta.content = reader.readCStringN(30, encoding: String.Encoding.shiftJIS.rawValue)!
    vmd.meta.modelName = reader.readCStringN(20, encoding: String.Encoding.shiftJIS.rawValue)!
    vmd.meta.totalFrameCount = reader.readIntN(4)
    vmd.meta.frameCount = 0
}

private func LoadVMDMotion(_ vmd: VMD, _ reader: DataReader) {
    for _ in 1...vmd.meta.totalFrameCount {
        let boneName = reader.readCStringN(15, encoding: String.Encoding.shiftJIS.rawValue)!

        var aTie = vmd.curveTies[boneName]
        if aTie == nil {
            aTie = CurveTie()
            aTie!.boneName = boneName
            vmd.curveTies[boneName] = aTie!
        }

        let tie = aTie!
        let frameNum = reader.readIntN(4)
        if vmd.meta.frameCount < frameNum {
            vmd.meta.frameCount = frameNum
        }

        var segTX = BezierSegment()
        var segTY = BezierSegment()
        var segTZ = BezierSegment()
        var segQX = BezierSegment()
        var segQY = BezierSegment()
        var segQZ = BezierSegment()
        var segQW = BezierSegment()

        segTX.value = reader.read()
        segTY.value = reader.read()
        segTZ.value = -reader.read()

        segQX.value = reader.read()
        segQY.value = reader.read()
        segQZ.value = -reader.read()
        segQW.value = -reader.read()

        let readPoint = { (index: Int) in
            // X_ax,Y_ax,Z_ax,R_ax
            let tx_x = Float(reader.readIntN(1))
            let ty_x = Float(reader.readIntN(1))
            let tz_x = Float(reader.readIntN(1))
            let qw_x = Float(reader.readIntN(1))

            // X_ay,Y_ay,Z_ay,R_ay
            let tx_y = Float(reader.readIntN(1))
            let ty_y = Float(reader.readIntN(1))
            let tz_y = Float(reader.readIntN(1))
            let qw_y = Float(reader.readIntN(1))

            segTX.controlPoint[index] = GLKVector2Make(tx_x, tx_y)
            segTY.controlPoint[index] = GLKVector2Make(ty_x, ty_y)
            segTZ.controlPoint[index] = GLKVector2Make(tz_x, tz_y)
            segQW.controlPoint[index] = GLKVector2Make(qw_x, qw_y)
        }
        readPoint(0)
        readPoint(1)

        var keyFrame = KeyFrame(frameNum)
        keyFrame.segments[BoneAttr.TX] = segTX
        keyFrame.segments[BoneAttr.TY] = segTY
        keyFrame.segments[BoneAttr.TZ] = segTZ
        keyFrame.segments[BoneAttr.QX] = segQX
        keyFrame.segments[BoneAttr.QY] = segQY
        keyFrame.segments[BoneAttr.QZ] = segQZ
        keyFrame.segments[BoneAttr.QW] = segQW

        tie.keys.append(keyFrame)

        reader.skip(48)
    }

    for (_, tie) in vmd.curveTies {
        tie.keys.sort {
            $0.frameNum < $1.frameNum
        }
    }
}

private func LoadVMDMorph(_ vmd: VMD, _ reader: DataReader) {
    let count = reader.readIntN(4)
    for _ in 0..<count {
        let m = VMDMorph(name: reader.readCStringN(15, encoding: String.Encoding.shiftJIS.rawValue)!, frameNum: reader.readIntN(4), weight: reader.read())
        if vmd.morphKeyFrames[m.frameNum] == nil {
            vmd.morphKeyFrames[m.frameNum] = []
        }
        vmd.morphKeyFrames[m.frameNum]!.append(m)
    }
}
