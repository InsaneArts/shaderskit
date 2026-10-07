#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of `pointerSplatField` (std/effects/pointerFields.ts) behind GridDistortion: a decaying
/// cursor-velocity splat field on one vec4 state buffer, settle-gated, published as an RG
/// displacement texture of `gridSize`² cells.
final class GridPointerSplatProgram: ComputeProgram {
    static let shaderNames = ["GridDistortion"]

    private static let maxCells = 128 * 128
    /// The grid size the shipped kernel was transpiled with (`20u` / `20.0f` literals).
    private static let bakedGrid = 20

    private let update: ComputeKernelDescriptor
    private let output: ComputeKernelDescriptor
    private let layout: UniformLayout
    private let buffer: MTLBuffer

    private var gridSize = 0
    private var dispTex: MTLTexture?
    private var library: MTLLibrary?
    private var needsZero = true

    private var prevX: Float = 0.5, prevY: Float = 0.5
    private var smoothVelX: Float = 0, smoothVelY: Float = 0
    private var settle = GridKit.SettleGate()

    init(context ctx: ComputeContext) throws {
        update = try GridKit.kernel(ctx, 0)
        output = try GridKit.kernel(ctx, 1)
        layout = try GridKit.uniformLayout(ctx, update)
        buffer = try GridKit.privateBuffer(ctx, length: Self.maxCells * 16, label: "GridDistortion state")
    }

    /// `clampSplatGridSize`.
    static func clampGrid(_ v: Float) -> Int { max(8, min(128, Int(v.rounded(.down)))) }

    /// The per-compose kernel factory (`makeSplatUpdateKernel(gridSize)`): rewrite the baked size.
    static func patches(gridSize n: Int) -> [GridKit.Patch] {
        if n == bakedGrid { return [] }
        return [GridKit.Patch("((cy * \(bakedGrid)u))", "((cy * \(n)u))", count: 2),
                GridKit.Patch("/ \(bakedGrid).0f))", "/ \(n).0f))", count: 2)]
    }

    /// A gridSize change recomposes upstream: every resource and tracker starts fresh.
    private func rebuild(_ ctx: ComputeContext, gridSize n: Int) throws {
        library = try GridKit.specializedLibrary(ctx, key: "grid\(n)", patches: Self.patches(gridSize: n))
        dispTex = try GridKit.texture(ctx, n, n, label: "GridDistortion displacement")
        gridSize = n
        needsZero = true
        prevX = 0.5; prevY = 0.5
        smoothVelX = 0; smoothVelY = 0
        settle = GridKit.SettleGate()
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        let n = Self.clampGrid(GridKit.num(ctx, "gridSize", 20))
        if n != gridSize || dispTex == nil { try rebuild(ctx, gridSize: n) }
        guard let dispTex, let library else { return ComputeOutputs() }
        if needsZero {
            GridKit.zero(textures: [dispTex], buffers: [buffer], cb: ctx.commandBuffer)
            needsZero = false
        }
        let out = ComputeOutputs(textures: ["compute_0": dispTex])

        let dt = min(ctx.frame.deltaTime, 0.016)
        // op.host('cursorVelocity')
        let px = ctx.frame.pointer.x, py = ctx.frame.pointer.y
        let velX: Float = dt > 0 ? (px - prevX) / dt : 0
        let velY: Float = dt > 0 ? (py - prevY) / dt : 0
        smoothVelX = smoothVelX * 0.85 + velX * 0.15
        smoothVelY = smoothVelY * 0.85 + velY * 0.15
        prevX = px; prevY = py
        settle.tick(active: abs(velX) + abs(velY) > 0.01)
        // op.settle: settle time derived from decay so residual displacement fully decays.
        let decay = GridKit.num(ctx, "decay", 3)
        let settleMs: Float = decay > 0 ? min(30000, (log(Float(1e-4)) / log(max(1e-6, 1 - decay * 0.016))) * 16.67) : 30000
        if settle.skip(settleMs: settleMs, dt: dt) { return out }

        let params = GridKit.pack(layout, [
            "cursorX": [px], "cursorY": [py], "mouseVelX": [smoothVelX], "mouseVelY": [smoothVelY],
            "dt": [dt], "decay": [decay], "intensity": [GridKit.num(ctx, "intensity", 1)],
            "radius": [GridKit.num(ctx, "radius", 1) * 0.05], "aspect": [Float(max(1, ctx.width)) / Float(max(1, ctx.height))],
        ])
        let kctx = GridKit.with(ctx, library: library)
        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return out }
        defer { enc.endEncoding() }
        enc.label = "GridDistortion splat"
        let threads = SIMD3<UInt32>(UInt32(n), UInt32(n), 1)
        try kctx.dispatch(enc, update, threads: threads) { e in
            GridKit.setBuffer(e, update, "buffer", buffer)
            GridKit.setUniform(e, update, params)
        }
        try kctx.dispatch(enc, output, threads: threads) { e in
            GridKit.setBuffer(e, output, "buffer", buffer)
            GridKit.setTexture(e, output, "dispTex", dispTex)
        }
        return out
    }
}

/// Port of `springLatticeField` (std/effects/pointerFields.ts) behind Liquify: a 64² spring-mass
/// cloth over two ping-pong vec4 buffers (A always current, B scratch), two substeps per frame,
/// cursor-impulse driven, settle-gated, published as an RG displacement texture.
final class GridSpringLatticeProgram: ComputeProgram {
    static let shaderNames = ["Liquify"]

    private static let grid = 64

    private let spring: ComputeKernelDescriptor
    private let output: ComputeKernelDescriptor
    private let layout: UniformLayout
    private let bufferA: MTLBuffer
    private let bufferB: MTLBuffer
    private let dispTex: MTLTexture
    private var needsZero = true

    private var prevX: Float = 0.5, prevY: Float = 0.5
    private var settle = GridKit.SettleGate()

    init(context ctx: ComputeContext) throws {
        spring = try GridKit.kernel(ctx, 0)
        output = try GridKit.kernel(ctx, 1)
        layout = try GridKit.uniformLayout(ctx, spring)
        let cells = Self.grid * Self.grid
        bufferA = try GridKit.privateBuffer(ctx, length: cells * 16, label: "Liquify A")
        bufferB = try GridKit.privateBuffer(ctx, length: cells * 16, label: "Liquify B")
        dispTex = try GridKit.texture(ctx, Self.grid, Self.grid, label: "Liquify displacement")
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        if needsZero {
            GridKit.zero(textures: [dispTex], buffers: [bufferA, bufferB], cb: ctx.commandBuffer)
            needsZero = false
        }
        let out = ComputeOutputs(textures: ["compute_0": dispTex])
        let dt = min(ctx.frame.deltaTime, 0.016)
        if dt <= 0 { return out } // zeroDt: 'skip'

        // op.host('cursorImpulse')
        let px = ctx.frame.pointer.x, py = ctx.frame.pointer.y
        let rawVelX = (px - prevX) / dt
        let rawVelY = (py - prevY) / dt
        let speed = (rawVelX * rawVelX + rawVelY * rawVelY).squareRoot()
        let clampedSpeed = min(speed, 3)
        prevX = px; prevY = py
        settle.tick(active: clampedSpeed > 0.01)
        let damping = GridKit.num(ctx, "damping", 3)
        if settle.skip(settleMs: damping > 0 ? min(30000, 5000 / damping) : 30000, dt: dt) { return out }

        let subDt = dt / 2
        let params = GridKit.pack(layout, [
            "cursorX": [px], "cursorY": [py],
            "dirX": [speed > 0.01 ? rawVelX / speed : 0], "dirY": [speed > 0.01 ? rawVelY / speed : 0],
            "clampedSpeed": [clampedSpeed], "dt": [dt], "subDt": [subDt],
            "stiffness": [GridKit.num(ctx, "stiffness", 3)],
            "dampFactor": [max(0, min(1, 1 - damping * subDt))],
            "radius": [GridKit.num(ctx, "radius", 1) * 0.08],
            "aspect": [Float(max(1, ctx.width)) / Float(max(1, ctx.height))],
        ])
        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return out }
        defer { enc.endEncoding() }
        enc.label = "Liquify springs"
        let threads = SIMD3<UInt32>(UInt32(Self.grid), UInt32(Self.grid), 1)
        // 2 substeps (A→B, B→A), then publish from A.
        for (read, write) in [(bufferA, bufferB), (bufferB, bufferA)] {
            try ctx.dispatch(enc, spring, threads: threads) { e in
                GridKit.setBuffer(e, spring, "readBuf", read)
                GridKit.setBuffer(e, spring, "writeBuf", write)
                GridKit.setUniform(e, spring, params)
            }
        }
        try ctx.dispatch(enc, output, threads: threads) { e in
            GridKit.setBuffer(e, output, "srcBuf", bufferA)
            GridKit.setTexture(e, output, "dispTex", dispTex)
        }
        return out
    }
}
#endif
