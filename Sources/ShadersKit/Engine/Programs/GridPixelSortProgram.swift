#if canImport(Metal)
import Foundation
import Metal
import simd

/// PixelSort (shaders/PixelSort, `buildOddEvenSortSet` in gpu/scaffolds/gridKernels.ts) on the
/// `gridSim` frame program: a luma prepass of the child, then `1 + round(strength·4)` brush-gated
/// odd-even compare-swap passes over a persistent per-cell offset map (parity and buffer side
/// alternate and persist across frames), then the sorted source coordinate is published.
///
/// The shipped kernels were transpiled for `axis: horizontal, direction: ascending`; the
/// `vertical` / `descending` variants upstream bakes per compose are specialized at runtime.
final class GridPixelSortProgram: ComputeProgram {
    static let shaderNames = ["PixelSort"]
    private static let work = 512

    private let luma: ComputeKernelDescriptor
    private let swap0: ComputeKernelDescriptor
    private let swap1: ComputeKernelDescriptor
    private let output: ComputeKernelDescriptor
    private let lumaLayout: UniformLayout
    private let swapLayout: UniformLayout
    private let bufferA: MTLBuffer
    private let bufferB: MTLBuffer
    private let lumaBuf: MTLBuffer
    private let stateTex: MTLTexture
    private var library: MTLLibrary?
    private var structure = ""
    private var needsZero = true

    // op.sortPass state (persists across frames) and the frame counter.
    private var sideA = true
    private var tick = 0
    private var frame = 0

    init(context ctx: ComputeContext) throws {
        luma = try GridKit.kernel(ctx, 0)
        swap0 = try GridKit.kernel(ctx, 1)
        swap1 = try GridKit.kernel(ctx, 2)
        output = try GridKit.kernel(ctx, 3)
        lumaLayout = try GridKit.uniformLayout(ctx, luma)
        swapLayout = try GridKit.uniformLayout(ctx, swap0)
        let bytes = Self.work * Self.work * 4
        bufferA = try GridKit.privateBuffer(ctx, length: bytes, label: "PixelSort A")
        bufferB = try GridKit.privateBuffer(ctx, length: bytes, label: "PixelSort B")
        lumaBuf = try GridKit.privateBuffer(ctx, length: bytes, label: "PixelSort luma")
        stateTex = try GridKit.texture(ctx, Self.work, Self.work, label: "PixelSort state")
    }

    /// The compile-time `vertical` / `direction` literals of the swap and publish kernels.
    static func patches(vertical: Bool, descending: Bool) -> [GridKit.Patch] {
        var p: [GridKit.Patch] = []
        if vertical {
            p += [
                GridKit.Patch("const uint lineC = cx;", "const uint lineC = cy;", count: 3),
                GridKit.Patch("const uint fixedC = cy;", "const uint fixedC = cx;", count: 2),
                GridKit.Patch("const uint partnerX = pClampedU;", "const uint partnerX = fixedC;", count: 2),
                GridKit.Patch("const uint partnerY = fixedC;", "const uint partnerY = pClampedU;", count: 2),
            ]
            for (name, c) in [("myIdx0", "myC0"), ("myIdx1", "myC1"), ("pIdx0", "pC0"), ("pIdx1", "pC1")] {
                p.append(GridKit.Patch("const uint " + name + " = ((((fixedC * 512u)) + wgsl_f2u(" + c + ")));",
                                       "const uint " + name + " = ((((wgsl_f2u(" + c + ") * 512u)) + fixedC));", count: 2))
            }
        }
        if descending {
            p.append(GridKit.Patch("((((myKey - partnerKey)) * 1.0f))", "((((myKey - partnerKey)) * (-1.0f)))", count: 2))
        }
        return p
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        guard let child = GridKit.child(ctx) else { return ComputeOutputs() } // op.readyWhen(lumaReady)
        // axis / direction are compile-time upstream: a change recomposes (fresh state).
        let vertical = GridKit.string(ctx, "axis") == "vertical"
        let descending = GridKit.string(ctx, "direction") == "descending"
        let key = "\(vertical ? "v" : "h")\(descending ? "d" : "a")"
        if key != structure || library == nil {
            library = try GridKit.specializedLibrary(ctx, key: key, patches: Self.patches(vertical: vertical, descending: descending))
            structure = key
            needsZero = true
            sideA = true; tick = 0; frame = 0
        }
        guard let library else { return ComputeOutputs() }
        if needsZero {
            GridKit.zero(textures: [stateTex], buffers: [bufferA, bufferB, lumaBuf], cb: ctx.commandBuffer)
            needsZero = false
        }

        // op.values('brush+decay')
        let dt = min(ctx.frame.deltaTime, 0.05)
        let strength = GridKit.num(ctx, "strength", 0.1)
        let decay = GridKit.num(ctx, "decay", 0.1)
        let passes = 1 + Int(GridKit.jsRound(strength * 4))
        let swapParams = GridKit.pack(swapLayout, [
            "mouseX": [ctx.frame.pointer.x], "mouseY": [ctx.frame.pointer.y],
            "radius": [GridKit.num(ctx, "radius", 0.4)], "falloff": [GridKit.num(ctx, "falloff", 1)],
            "decay": [decay * dt * 2 / Float(passes)], // spread across passes → rate independent of strength
            "aspect": [Float(max(1, ctx.width)) / Float(max(1, ctx.height))],
            "seed": [Float(frame % 1024)],
        ])
        let lumaParams = GridKit.pack(lumaLayout, ["inputWidth": [Float(child.width)], "inputHeight": [Float(child.height)]])

        let out = ComputeOutputs(textures: ["compute_0": stateTex])
        let kctx = GridKit.with(ctx, library: library)
        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return out }
        defer { enc.endEncoding() }
        enc.label = "PixelSort"
        let threads = SIMD3<UInt32>(UInt32(Self.work), UInt32(Self.work), 1)
        try kctx.dispatch(enc, luma, threads: threads) { e in
            GridKit.setTexture(e, luma, "input", child)
            GridKit.setBuffer(e, luma, "lumaBuf", lumaBuf)
            GridKit.setUniform(e, luma, lumaParams)
        }
        // op.sortPass
        for _ in 0..<passes {
            let k = tick % 2 == 1 ? swap1 : swap0
            let (read, write) = sideA ? (bufferA, bufferB) : (bufferB, bufferA)
            try kctx.dispatch(enc, k, threads: threads) { e in
                GridKit.setBuffer(e, k, "readBuf", read)
                GridKit.setBuffer(e, k, "writeBuf", write)
                GridKit.setBuffer(e, k, "lumaBuf", lumaBuf)
                GridKit.setUniform(e, k, swapParams)
            }
            sideA.toggle()
            tick += 1
        }
        // op.publish from the side holding the current order.
        let current = sideA ? bufferA : bufferB
        try kctx.dispatch(enc, output, threads: threads) { e in
            GridKit.setBuffer(e, output, "srcBuf", current)
            GridKit.setTexture(e, output, "stateTex", stateTex)
        }
        frame += 1
        return out
    }
}
#endif
