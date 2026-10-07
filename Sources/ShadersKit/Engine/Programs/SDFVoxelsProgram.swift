#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of upstream `createVoxelFieldComputeNode` (gpu/kit/voxels.ts) as `voxelSurface` drives it
/// (std/paint/voxels.ts): an occupancy-grid bake, a light-space shadow map and the voxel G-buffer march,
/// each on its own dirty key, publishing `_vf*` and the `_vx*` reconstruction fields. `compute_0` is the
/// field, `compute_1` the shadow map.
final class SDFVoxelsProgram: ComputeProgram {
    static let shaderNames = ["Voxels"]

    private static let halfDiagonal = 0.8660254
    /// The shadow-map resolution is baked into the generated march and fragment (`RES = 1024`), so it
    /// stays at the desktop value on every device.
    private static let shadowRes = 1024

    private let gridMax: Int
    private let fieldTexture: MTLTexture
    private let shadowTexture: MTLTexture
    private let occ: MTLBuffer
    private let maxRes: Int
    private let kMarch: ComputeKernelDescriptor
    private let kBake: ComputeKernelDescriptor
    private let kShadow: ComputeKernelDescriptor
    private let marchLayout: UniformLayout
    private let voxLayout: UniformLayout
    private let marchEvery: Int

    private var setup: SDFShape3DSetup
    private var library: MTLLibrary
    private var routeKey: String
    private var activeRes: Int
    private var lastMarchKey: [Double]? = nil
    private var lastBakeKey: [Double]? = nil
    private var lastShadowKey: [Double]? = nil
    private var changedFrames = 0
    private var lastRBound = 0.6
    private var voxel = 0.03
    private var published: [String: [Float]] = [:]

    init(context ctx: ComputeContext) throws {
        guard let info = ctx.descriptor.compute, let k0 = info.kernel(0), let k1 = info.kernel(1), let k2 = info.kernel(2),
              let ml = info.uniformLayouts["params"], let vl = info.uniformLayouts["vox"] else {
            throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) voxel kernels")
        }
        kMarch = k0
        kBake = k1
        kShadow = k2
        marchLayout = ml
        voxLayout = vl
        let mobile = SDFKit.isMobileGpuViewport
        gridMax = mobile ? 128 : 192
        let words = Int((Double(gridMax) / 4).rounded(.up)) * gridMax * gridMax
        maxRes = SDFKit.volumetricFieldRes
        guard let field = ctx.makeTexture(width: maxRes, height: maxRes, format: .rgba32Float, label: "Voxels field"),
              let shadow = ctx.makeTexture(width: Self.shadowRes, height: Self.shadowRes, format: .r32Float, label: "Voxels shadow map"),
              let buf = ctx.device.device.makeBuffer(length: words * 4, options: [.storageModePrivate]) else {
            throw ShaderEngineError.noMetalDevice
        }
        buf.label = "Voxels occupancy"
        fieldTexture = field
        shadowTexture = shadow
        occ = buf
        SDFKit.clear(field, to: MTLClearColor(red: 1000, green: 0, blue: 0, alpha: 0), commandBuffer: ctx.commandBuffer)
        SDFKit.clear(shadow, to: MTLClearColor(red: 1e9, green: 0, blue: 0, alpha: 0), commandBuffer: ctx.commandBuffer)
        activeRes = maxRes
        marchEvery = mobile ? 2 : 1
        published = [
            "_vfOriginX": [0], "_vfOriginY": [0], "_vfSpanX": [1], "_vfSpanY": [1], "_vfActiveRes": [1], "_vfRBound": [0.6],
        ]
        let route = SDFVolumetricField.route(ctx)
        routeKey = route.key
        // Placeholders until `makeSetup` (needs `self` for the live extra pad).
        setup = SDFShape3DSetup(type: route.type, initialConfig: route.config, shapeJSON: nil)
        library = ctx.library
        voxel = clampVoxel(number(ctx, "voxelSize", 0.03), rBound: lastRBound)
        setup = makeSetup(route, ctx)
        library = try SDFShapeKernels.library(ctx, shapeType: route.type)
    }

    /// Voxels puff past the smooth surface by up to half a cell diagonal: the setup grows its bounding
    /// sphere and field domain by it (read live).
    private func makeSetup(_ route: (type: String?, config: [String: Any], key: String), _ ctx: ComputeContext) -> SDFShape3DSetup {
        SDFShape3DSetup(type: route.type, initialConfig: route.config, shapeJSON: ctx.string("shape")) { [unowned self] in
            self.voxel * Self.halfDiagonal + 0.01
        }
    }

    /// Upstream `clampVoxel`.
    private func clampVoxel(_ size: Double, rBound: Double) -> Double {
        let minCell = (2 * (rBound + 0.002)) / Double(gridMax)
        return max(size.isFinite ? size : 0.03, minCell, 0.002)
    }

    private func number(_ ctx: ComputeContext, _ name: String, _ fallback: Double) -> Double {
        SDFKit.number(ctx, name, fallback)
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        let route = SDFVolumetricField.route(ctx)
        if route.key != routeKey {
            routeKey = route.key
            setup = makeSetup(route, ctx)
            library = try SDFShapeKernels.library(ctx, shapeType: route.type)
            lastMarchKey = nil
            lastBakeKey = nil
            lastShadowKey = nil
        }
        // voxelSurface `getValues` (Voxels declares no pitch / yaw / spin).
        let voxelSize = number(ctx, "voxelSize", 0.03)
        let fillValue = number(ctx, "fill", 0)
        let voxelScaleValue = number(ctx, "voxelScale", 1)
        let bevelValue = number(ctx, "bevel", 0)
        let pitchDeg = 0.0
        let yawDeg = 0.0
        let lightAngle = number(ctx, "lightAngle", 225)
        let lightElevation = number(ctx, "lightElevation", 45)
        let gridSpace = ctx.string("gridSpace") == "view" ? "view" : "shape"

        voxel = clampVoxel(voxelSize, rBound: lastRBound)
        setup.update(shapeJSON: ctx.string("shape"), deltaTime: Double(ctx.frame.deltaTime), pointer: SIMD2(Double(ctx.frame.pointer.x), Double(ctx.frame.pointer.y)))
        let fp = setup.footprint
        lastRBound = fp.rBound
        voxel = clampVoxel(voxel, rBound: fp.rBound)
        let scale = number(ctx, "scale", 1)
        activeRes = SDFKit.resolveActiveFieldRes(spanX: fp.spanX, spanY: fp.spanY, scale: scale, canvasHeightDevicePx: Double(ctx.height), maxRes: maxRes, prevRes: activeRes)

        // View → grid: camera (pitch about x, yaw about y) then the shape rotation.
        let deg = Double.pi / 180
        let pitch = pitchDeg * deg, yaw = yawDeg * deg
        let cam = SDFKit.Rotation(cx: cos(pitch), sx: sin(pitch), cy: cos(yaw), sy: sin(yaw), cz: 1, sz: 0)
        let rot = setup.rotation
        func R(_ v: SIMD3<Double>) -> SIMD3<Double> { SDFKit.rotateVec(SDFKit.rotateVec(v, cam), rot) }
        let mx = R(SIMD3(1, 0, 0)), my = R(SIMD3(0, 1, 0)), mz = R(SIMD3(0, 0, 1))

        // Key light: material convention (x right, y down, z into the scene) → view → grid space.
        let az = lightAngle * deg
        let el = min(89, max(1, lightElevation)) * deg
        let lv = SIMD3(cos(az) * cos(el), -sin(az) * cos(el), -sin(el))
        let lg = gridSpace == "shape" ? R(lv) : lv
        let helper: SIMD3<Double> = abs(lg.x) < 0.9 ? SIMD3(1, 0, 0) : SIMD3(0, 1, 0)
        let t1 = simd_normalize(simd_cross(lg, helper))
        let t2 = simd_cross(lg, t1)

        let gridOrigin = -fp.rBound
        let gridN = min(gridMax, Int(((2 * fp.rBound) / voxel).rounded(.up)))
        let gridW = Int((Double(gridN) / 4).rounded(.up))
        let fill = min(0.5, max(-0.5, fillValue))
        let voxelScale = min(1, max(0.2, voxelScaleValue))
        let bevel = min(1, max(0, bevelValue))
        let voxBytes = SDFKit.pack(voxLayout, [
            "cam.cx": [Float(cam.cx)], "cam.sx": [Float(cam.sx)], "cam.cy": [Float(cam.cy)],
            "cam.sy": [Float(cam.sy)], "cam.cz": [Float(cam.cz)], "cam.sz": [Float(cam.sz)],
            "lightDir": [Float(lg.x), Float(lg.y), Float(lg.z)], "voxelSize": [Float(voxel)],
            "lightT1": [Float(t1.x), Float(t1.y), Float(t1.z)], "fill": [Float(fill)],
            "lightT2": [Float(t2.x), Float(t2.y), Float(t2.z)], "voxelScale": [Float(voxelScale)],
            "bevel": [Float(bevel)], "gridOrigin": [Float(gridOrigin)], "gridN": [Float(gridN)], "gridW": [Float(gridW)],
        ])

        // Three dirty keys: grid (geometry + cell size + fill, + view for a screen-aligned grid),
        // shadow (grid + sub-shape + light), march (grid + sub-shape + view + active res).
        let gridKey: [Double] = gridSpace == "view"
            ? setup.stateKey + [pitchDeg, yawDeg, voxel, fill, Double(gridN)]
            : setup.geometryKey + [voxel, fill, Double(gridN)]
        let subShapeKey = [voxelScale, bevel]
        let lightKey = [lg.x, lg.y, lg.z]
        let bakeKey = gridKey
        let shadowKey = gridKey + subShapeKey + lightKey
        let marchKey = gridKey + subShapeKey + setup.stateKey + [pitchDeg, yawDeg, Double(activeRes)]
        let rebake = bakeKey != lastBakeKey
        let reshadow = shadowKey != lastShadowKey
        let remarch = marchKey != lastMarchKey
        guard rebake || reshadow || remarch else { return outputs() }
        if remarch {
            changedFrames += 1
            if marchEvery > 1 && changedFrames % marchEvery != 0 && !rebake { return outputs() }
        }
        lastBakeKey = bakeKey
        lastShadowKey = shadowKey
        if reshadow {
            published["_vxL"] = [Float(lg.x), Float(lg.y), Float(lg.z)]
            published["_vxT1"] = [Float(t1.x), Float(t1.y), Float(t1.z)]
            published["_vxT2"] = [Float(t2.x), Float(t2.y), Float(t2.z)]
        }
        if remarch {
            lastMarchKey = marchKey
            setup.setActiveRes(activeRes)
            published["_vfOriginX"] = [Float(fp.originX)]
            published["_vfOriginY"] = [Float(fp.originY)]
            published["_vfSpanX"] = [Float(fp.spanX)]
            published["_vfSpanY"] = [Float(fp.spanY)]
            published["_vfActiveRes"] = [Float(activeRes)]
            published["_vfRBound"] = [Float(fp.rBound)]
            published["_vxMx"] = [Float(mx.x), Float(mx.y), Float(mx.z)]
            published["_vxMy"] = [Float(my.x), Float(my.y), Float(my.z)]
            published["_vxMz"] = [Float(mz.x), Float(mz.y), Float(mz.z)]
            published["_vxVoxel"] = [Float(voxel)]
            published["_vxGridOrigin"] = [Float(gridOrigin)]
        }
        let marchBytes = SDFKit.pack(marchLayout, setup.marchValues)

        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return outputs() }
        defer { enc.endEncoding() }
        enc.label = "Voxels pre-march"
        let lib = library
        func bindCommon(_ e: MTLComputeCommandEncoder, _ k: ComputeKernelDescriptor) {
            if let s = k.buffer("vox") { SDFKit.setBytes(e, voxBytes, index: s.slot) }
            if let s = k.buffer("params") { SDFKit.setBytes(e, marchBytes, index: s.slot) }
            if let s = k.buffer("occ") { e.setBuffer(occ, offset: 0, index: s.slot) }
        }
        if rebake {
            try SDFKit.dispatch(ctx, enc, kBake, library: lib, threads: SIMD3(UInt32(gridW), UInt32(gridN), UInt32(gridN))) { e in
                bindCommon(e, kBake)
            }
        }
        if reshadow {
            try SDFKit.dispatch(ctx, enc, kShadow, library: lib, threads: SIMD3(UInt32(Self.shadowRes), UInt32(Self.shadowRes), 1)) { e in
                bindCommon(e, kShadow)
                if let s = kShadow.texture("shadowMap") { e.setTexture(shadowTexture, index: s.slot) }
            }
        }
        if remarch {
            try SDFKit.dispatch(ctx, enc, kMarch, library: lib, threads: SIMD3(UInt32(activeRes), UInt32(activeRes), 1)) { e in
                bindCommon(e, kMarch)
                if let s = kMarch.texture("field_1") ?? kMarch.textures.first { e.setTexture(fieldTexture, index: s.slot) }
            }
        }
        return outputs()
    }

    private func outputs() -> ComputeOutputs {
        ComputeOutputs(textures: ["compute_0": fieldTexture, "compute_1": shadowTexture], extraFields: published)
    }
}
#endif
