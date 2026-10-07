#if canImport(Metal)
import Foundation
import Metal
import simd

/// ReactionDiffusion (shaders/ReactionDiffusion) on the `gridSim` frame program: Gray-Scott over two
/// ping-pong vec2f (U,V) buffers on a 512² grid. Per frame: [seed on (re)init or preset change] →
/// reaction × round(speed) → publish the current side into an rgba16float texture.
///
/// Upstream binds a second "drive" kernel variant when a child is nested (the child's luminance
/// biases feed/kill per cell). The transpiler emitted only the generator variant, so a nested
/// child does not modulate the pattern here.
final class GridReactionDiffusionProgram: ComputeProgram {
    static let shaderNames = ["ReactionDiffusion"]

    private static let n = 512
    private static let maxIterations: Float = 16
    /// Named Gray-Scott regimes → (feed, kill).
    static let presets: [String: (feed: Float, kill: Float)] = [
        "coral": (0.0545, 0.0620), "mitosis": (0.0367, 0.0649), "spots": (0.0300, 0.0620),
        "maze": (0.0290, 0.0570), "worms": (0.0780, 0.0610), "fingerprints": (0.0370, 0.0600),
        "holes": (0.0390, 0.0580), "solitons": (0.0740, 0.0640), "bubbles": (0.0980, 0.0555),
        "waves": (0.0140, 0.0450), "flowers": (0.0620, 0.06093),
    ]

    private let output: ComputeKernelDescriptor
    private let seed: ComputeKernelDescriptor
    private let react: ComputeKernelDescriptor
    private let layout: UniformLayout
    private var state: GridKit.PingPong<MTLBuffer>
    private let outTex: MTLTexture
    private var needsZero = true

    private var needsSeed = true
    private var lastPreset = ""
    private var pointer = GridKit.PointerTracker()

    init(context ctx: ComputeContext) throws {
        output = try GridKit.kernel(ctx, 0)
        seed = try GridKit.kernel(ctx, 1)
        react = try GridKit.kernel(ctx, 2)
        layout = try GridKit.uniformLayout(ctx, react)
        let bytes = Self.n * Self.n * 8
        state = GridKit.PingPong(try GridKit.privateBuffer(ctx, length: bytes, label: "ReactionDiffusion A"),
                                 try GridKit.privateBuffer(ctx, length: bytes, label: "ReactionDiffusion B"))
        outTex = try GridKit.texture(ctx, Self.n, Self.n, label: "ReactionDiffusion field")
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        if needsZero {
            GridKit.zero(textures: [outTex], buffers: [state.a, state.b], cb: ctx.commandBuffer)
            needsZero = false
        }
        let N = Float(Self.n)
        // op.values('feed/kill+brush')
        let aspect: Float = ctx.height > 0 ? Float(ctx.width) / Float(ctx.height) : 1
        let preset = GridKit.string(ctx, "preset").flatMap { $0.isEmpty ? nil : $0 } ?? "coral"
        if preset != lastPreset { lastPreset = preset; needsSeed = true }
        let pk = Self.presets[preset]
        let feed = pk?.feed ?? GridKit.num(ctx, "feed", 0.055)
        let kill = pk?.kill ?? GridKit.num(ctx, "kill", 0.062)

        // Map the pointer into field space with the fragment's cover + aspect + feature-size fit.
        let featureSize = max(GridKit.num(ctx, "featureSize", 3), 0.0001)
        let view = 1 / featureSize
        let sx = min(aspect, 1)
        let sy = min(1 / aspect, 1)
        let move = pointer.update(ctx.frame.pointer, dt: 0.016)
        let fieldX = (move.x - 0.5) * sx * view + 0.5
        let fieldY = (move.y - 0.5) * sy * view + 0.5
        let cursorSpeed = (move.dx * move.dx + move.dy * move.dy).squareRoot()
        let brushStrength = GridKit.num(ctx, "brushStrength", 0.6)
        let moving = cursorSpeed > 0.0005 && brushStrength > 0
        let velScale: Float = moving ? min(cursorSpeed / 0.02, 1) : 0
        let brushRadGrid = GridKit.num(ctx, "brushSize", 0.04) * N * view
        let invRaw = ctx.props["childInvert"]?.boolValue ?? false
        let iters = Int(min(Self.maxIterations, max(1, GridKit.jsRound(GridKit.num(ctx, "speed", 6)))))
        let params = GridKit.pack(layout, [
            "feed": [feed], "kill": [kill], "dv": [GridKit.num(ctx, "diffusionRatio", 0.5)],
            "brushRadSq": [brushRadGrid * brushRadGrid], "brushStrength": [brushStrength],
            "cursorX": [fieldX * N], "cursorY": [fieldY * N], "cursorActive": [velScale],
            "driveInfluence": [GridKit.num(ctx, "childInfluence", 0.6)],
            "driveContrast": [GridKit.num(ctx, "childContrast", 0.5)],
            "driveThreshold": [GridKit.num(ctx, "childThreshold", 0.5)],
            "driveInvert": [invRaw ? 1 : 0],
            "driveMapX": [1 / (sx * view)], "driveMapY": [1 / (sy * view)],
            "_pad0": [0], "_pad1": [0],
        ])

        let out = ComputeOutputs(textures: ["compute_0": outTex])
        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return out }
        defer { enc.endEncoding() }
        enc.label = "ReactionDiffusion"
        let threads = SIMD3<UInt32>(UInt32(Self.n), UInt32(Self.n), 1)
        // op.seedOnce: the seed writes bufferA, so a re-seed also resets the orientation.
        if needsSeed {
            needsSeed = false
            state.reset()
            let a = state.a
            try ctx.dispatch(enc, seed, threads: threads) { e in GridKit.setBuffer(e, seed, "stateBuf", a) }
        }
        // op.iterate
        for _ in 0..<iters {
            let read = state.read, write = state.write
            try ctx.dispatch(enc, react, threads: threads) { e in
                GridKit.setBuffer(e, react, "readBuf", read)
                GridKit.setBuffer(e, react, "writeBuf", write)
                GridKit.setUniform(e, react, params)
            }
            state.swap()
        }
        // op.publish: the side holding the current state.
        let current = state.read
        try ctx.dispatch(enc, output, threads: threads) { e in
            GridKit.setBuffer(e, output, "srcBuf", current)
            GridKit.setTexture(e, output, "outTex", outTex)
        }
        return out
    }
}
#endif
