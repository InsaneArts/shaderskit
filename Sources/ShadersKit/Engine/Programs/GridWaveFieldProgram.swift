#if canImport(Metal)
import Foundation
import Metal
import simd

/// Port of the `simulate.grid` wave word as lowered for CursorRipples (`waves.createWaveFieldSim`,
/// gpu/kit/waves.ts): a damped 2-history wave equation over a 128² height field (ping-pong f32
/// buffers), stirred by the teleport-guarded pointer, its gradient published as an RG
/// displacement texture. The settle window derives from the damping value.
final class GridWaveFieldProgram: ComputeProgram {
    static let shaderNames = ["CursorRipples"]

    private static let resolution = 128
    /// `op.wave` damping-prop → per-step damp factor curve.
    private static let dampingScale: Float = 0.004
    /// `op.splat` radius: UI radius (0.1–1) → field-space brush radius.
    private static let radiusScale: Float = 0.05
    /// `pointerSpeed({max: 2})`.
    private static let speedMax: Float = 2

    private let propagate: ComputeKernelDescriptor
    private let gradient: ComputeKernelDescriptor
    private let layout: UniformLayout
    private var field: GridKit.PingPong<MTLBuffer>
    private let dispTex: MTLTexture
    private var needsZero = true

    private var pointer = GridKit.PointerTracker()
    private var lastActiveMs: Float

    init(context ctx: ComputeContext) throws {
        propagate = try GridKit.kernel(ctx, 0)
        gradient = try GridKit.kernel(ctx, 1)
        layout = try GridKit.uniformLayout(ctx, propagate)
        let cells = Self.resolution * Self.resolution
        field = GridKit.PingPong(try GridKit.privateBuffer(ctx, length: cells * 4, label: "CursorRipples A"),
                                 try GridKit.privateBuffer(ctx, length: cells * 4, label: "CursorRipples B"))
        dispTex = try GridKit.texture(ctx, Self.resolution, Self.resolution, label: "CursorRipples displacement")
        lastActiveMs = ctx.frame.time * 1000
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        if needsZero {
            GridKit.zero(textures: [dispTex], buffers: [field.a, field.b], cb: ctx.commandBuffer)
            needsZero = false
        }
        let out = ComputeOutputs(textures: ["compute_0": dispTex])
        // Upstream measures the settle window on the wall clock; the frame clock stands in for it.
        let nowMs = ctx.frame.time * 1000
        let dt = min(ctx.frame.deltaTime, 0.016)
        let aspect = Float(max(1, ctx.width)) / Float(max(1, ctx.height))
        let damping = GridKit.num(ctx, "decay", 10)
        let radius = GridKit.num(ctx, "radius", 0.5) * Self.radiusScale

        // velX/velY are zeroed on a teleport frame, so no impulse comes out of a jump.
        let move = pointer.update(ctx.frame.pointer, dt: dt)
        let cursorSpeed = min((move.velX * move.velX + move.velY * move.velY).squareRoot(), Self.speedMax)
        if cursorSpeed > 0.01 { lastActiveMs = nowMs }

        // At-rest skip: settle time derived from the damping parameter.
        let dampFactor = 1 - damping * Self.dampingScale
        let settleMs: Float = dampFactor >= 1 ? .infinity : min(30000, (log(Float(1e-6)) / log(max(dampFactor, 0.001))) * 16.67)
        if nowMs - lastActiveMs > settleMs { return out }

        let params = GridKit.pack(layout, [
            "cursorX": [move.x], "cursorY": [move.y], "cursorSpeed": [cursorSpeed], "dt": [dt],
            "damping": [damping], "radius": [radius], "aspect": [aspect],
        ])
        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return out }
        defer { enc.endEncoding() }
        enc.label = "CursorRipples waves"
        let threads = SIMD3<UInt32>(UInt32(Self.resolution), UInt32(Self.resolution), 1)
        let read = field.read, write = field.write
        try ctx.dispatch(enc, propagate, threads: threads) { e in
            GridKit.setBuffer(e, propagate, "readBuf", read)
            GridKit.setBuffer(e, propagate, "writeBuf", write)
            GridKit.setUniform(e, propagate, params)
        }
        // The gradient reads the buffer just written.
        try ctx.dispatch(enc, gradient, threads: threads) { e in
            GridKit.setBuffer(e, gradient, "srcBuf", write)
            GridKit.setTexture(e, gradient, "dispTex", dispTex)
        }
        field.swap()
        return out
    }
}
#endif
