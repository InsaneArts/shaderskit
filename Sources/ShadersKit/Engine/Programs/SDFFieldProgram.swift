#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of upstream `shapedSurface`'s compute half (std/paint/materials.ts →
/// `createVolumetricFieldComputeNode`): the shape prop is pre-marched into the rgba32float field the
/// fragment samples as `compute_0`, re-marched only when the shape state changes, with the `_vf*` sample
/// domain published as extra fields. Nebula adds its `onBeforeRender` color-space ramp endpoints.
final class SDFFieldProgram: ComputeProgram {
    static let shaderNames = [
        "BrushedMetal", "CarbonFiber", "Chrome", "Crystal", "Emboss", "Frost", "Glass", "Goo",
        "Heatmap", "Hologram", "Holographic", "LightEdge", "LiquidMetal", "Nebula", "Neon",
        "Obsidian", "Plastic", "ThinFilm", "Water",
    ]

    private let field: SDFVolumetricField
    private var nebulaKey: [Float]? = nil
    private var nebulaFields: [String: [Float]] = [:]

    init(context ctx: ComputeContext) throws {
        field = try SDFVolumetricField(context: ctx)
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        if try field.prepare(ctx) {
            guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return ComputeOutputs() }
            defer { enc.endEncoding() }
            enc.label = "\(ctx.descriptor.name) volumetric field"
            try field.encode(enc, ctx)
        }
        var extra = field.extraFields
        if ctx.descriptor.name == "Nebula" {
            updateNebulaRamp(ctx)
            extra.merge(nebulaFields) { _, n in n }
        }
        return ComputeOutputs(textures: ["compute_0": field.texture], extraFields: extra)
    }

    /// Nebula's `onBeforeRender`: for a non-linear color space the three ramp endpoints are converted
    /// into the mix space once per change (`convVeil` / `convGas` / `convCore`). Linear never writes them.
    private func updateNebulaRamp(_ ctx: ComputeContext) {
        let spaceMode = Int(ctx.scalar("colorSpace"))
        guard spaceMode != 0 else { return }
        let names = ["veilColor", "gasColor", "coreColor"]
        let cols = names.compactMap { SDFKit.uniform(ctx, "n_x.\($0)") }
        guard cols.count == names.count, cols.allSatisfy({ $0.count >= 3 }) else { return }
        let key = cols.flatMap { $0.prefix(3) } + [Float(spaceMode)]
        if key == nebulaKey { return }
        nebulaKey = key
        for (idx, name) in ["convVeil", "convGas", "convCore"].enumerated() {
            let c = cols[idx]
            let conv = ColorMath.convertP3ToMixSpaceCPU(r: c[0], g: c[1], b: c[2], mode: spaceMode)
            nebulaFields[name] = [conv.x, conv.y, conv.z]
        }
    }
}
#endif
