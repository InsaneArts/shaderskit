#if canImport(Metal)
import Foundation
import Metal
import simd

/// The per-shader half of an agent simulation: upstream's `bake` (pipelines, program, init step)
/// and `frame` (the per-frame uniform math) for one shader, over the shared `AgentSystem` harness.
protocol AgentSimulation: AnyObject {
    var system: AgentSystem { get }
    /// Writes this frame's uniforms and returns its dispatches in order. `nil` skips the frame and
    /// keeps the last resolved texture on screen (upstream returning `null` from `getComputeNodes`).
    func frame(_ ctx: ComputeContext) throws -> [AgentSystem.Dispatch]?
}

/// Port of the `agentSim` noun (std/sim/agents.ts) for the six agent/particle shaders. Kernel
/// indices follow the generated `<Shader>_k<N>` order, which is the order upstream creates the
/// pipelines in (see each descriptor's recorded `drive`).
final class AgentSystemProgram: ComputeProgram {
    static let shaderNames = ["Boids", "FloatingParticles", "MagneticFilings", "ParticleField", "ParticleFlow", "Particles"]

    private let sim: AgentSimulation
    private var hasOutput = false

    init(context ctx: ComputeContext) throws {
        switch ctx.descriptor.name {
        case "Boids": sim = try BoidsSimulation(ctx)
        case "FloatingParticles": sim = try FloatingParticlesSimulation(ctx)
        case "MagneticFilings": sim = try MagneticFilingsSimulation(ctx)
        case "ParticleField": sim = try ParticleFieldSimulation(ctx)
        case "ParticleFlow": sim = try ParticleFlowSimulation(ctx)
        case "Particles": sim = try ParticlesSimulation(ctx)
        default: throw ShaderEngineError.missingFunction("\(ctx.descriptor.name) agent simulation")
        }
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        if let steps = try sim.frame(ctx), !steps.isEmpty {
            try sim.system.encode(ctx, steps)
            hasOutput = true
        }
        // Before the first resolve the texture is undefined: leave `compute_0` to the placeholder.
        return hasOutput ? ComputeOutputs(textures: ["compute_0": sim.system.output]) : ComputeOutputs()
    }
}

// MARK: - Boids (shaders/Boids)

final class BoidsSimulation: AgentSimulation {
    private static let maxAgents = 4096
    private static let res = 1024
    private static let baseSpeed: Float = 0.13
    private static let forceRatio: Float = 3.5

    let system: AgentSystem

    init(_ ctx: ComputeContext) throws {
        system = try AgentSystem(context: ctx, config: .init(
            maxAgents: Self.maxAgents, countCap: Self.maxAgents,
            outputWidth: Self.res, outputHeight: Self.res,
            pipelines: [
                "init": .init(kernel: 0, threads: .max),
                "update": .init(kernel: 1, threads: .agents),
                "splat": .init(kernel: 2, threads: .agents),
                "resolve": .init(kernel: 3, threads: .fixed(Self.res, Self.res)),
            ],
            program: ["update", "splat", "resolve"], initStep: "init"))
    }

    func frame(_ ctx: ComputeContext) -> [AgentSystem.Dispatch]? {
        let f = AgentFrame(ctx)
        let domainX = max(f.aspect, 0.01)
        let count = system.resolveCount(ctx.agentNumber("count", 2000))
        let seed = ctx.agentNumber("seed", 0)
        let maxSpeed = Self.baseSpeed * ctx.agentNumber("speed", 2)
        let maxForce = maxSpeed * Self.forceRatio
        let perception = ctx.agentNumber("perception", 0.12)
        let modeStr = ctx.string("cursorMode") ?? "repel"
        let cursorMode: Float = modeStr == "attract" ? 1 : modeStr == "repel" ? 2 : 0
        // Pointer arrives in screen UV (y down); x is lifted into world units (× aspect).
        let cursorRadius: Float = 0.22
        let bodyR = min(max(ctx.agentNumber("size", 1.5), 0.5), 3) * 2 / AgentMath.sizeRefRes
        let sep = perception * 0.5

        system.writeParams(ctx, [
            "colA": ctx.agentColor("colorA", fallback: SIMD4(0.56, 0.77, 1, 1)),
            "colB": ctx.agentColor("colorB", fallback: SIMD4(1, 0.48, 0.85, 1)),
            "count": [Float(count)],
            "trails": [AgentMath.clamp01(ctx.agentNumber("trails", 0.35)) * 0.92],
            "dt": [f.dt], "aspect": [f.aspect], "domainX": [domainX],
            "maxSpeed": [maxSpeed], "maxForce": [maxForce],
            "perceptionSq": [perception * perception],
            "sepRadiusSq": [sep * sep],
            "sepW": [ctx.agentNumber("separation", 1.7)],
            "aliW": [ctx.agentNumber("alignment", 1.5)],
            "cohW": [ctx.agentNumber("cohesion", 1)],
            "cursorX": [f.pointerX * f.aspect], "cursorY": [f.pointerY], "cursorMode": [cursorMode],
            "cursorRadius": [cursorRadius], "cursorRadiusSq": [cursorRadius * cursorRadius],
            "cursorForce": [ctx.agentNumber("cursorStrength", 1.5) * maxSpeed * 12],
            "bodyR": [bodyR],
            "margin": [0.07], "turnForce": [maxSpeed * 2.2],
            "seed": [seed],
        ])
        // `seed` re-dispatches the one-shot spawn.
        return system.frame(count: count, reseed: seed)
    }
}

// MARK: - FloatingParticles (shaders/FloatingParticles)

final class FloatingParticlesSimulation: AgentSimulation {
    private static let maxMotes = 8192
    private static let res = 1024
    private static let baseDrift: Float = 0.12
    private static let cursorForceK: Float = 3.5
    private static let cursorDrag: Float = 1.1

    let system: AgentSystem
    private var localTime: Double = 0

    init(_ ctx: ComputeContext) throws {
        system = try AgentSystem(context: ctx, config: .init(
            maxAgents: Self.maxMotes, countCap: Self.maxMotes,
            outputWidth: Self.res, outputHeight: Self.res,
            pipelines: [
                "init": .init(kernel: 0, threads: .max),
                "update": .init(kernel: 1, threads: .agents),
                "splat": .init(kernel: 2, threads: .agents),
                "resolve": .init(kernel: 3, threads: .fixed(Self.res, Self.res)),
            ],
            program: ["update", "splat", "resolve"], initStep: "init"))
    }

    func frame(_ ctx: ComputeContext) -> [AgentSystem.Dispatch]? {
        let f = AgentFrame(ctx)
        localTime += Double(f.dt)
        let domainX = max(f.aspect, 0.01)
        let count = system.resolveCount(ctx.agentNumber("count", 1200))
        let cursorRadius: Float = 0.22
        let bodyR = min(max(ctx.agentNumber("particleSize", 1.2), 0.3), 4) * 2 / AgentMath.sizeRefRes

        system.writeParams(ctx, [
            "color": ctx.agentColor("particleColor", fallback: SIMD4(1, 1, 1, 1)),
            "count": [Float(count)], "dt": [f.dt], "time": [Float(localTime)],
            "aspect": [f.aspect], "domainX": [domainX],
            "driftBase": [min(max(ctx.agentNumber("speed", 0.25), 0), 1.5) * Self.baseDrift / 0.25],
            // The heading is flipped 180° to keep the legacy (procedural) drift direction.
            "angleRad": [ctx.agentNumber("angle", 90) * AgentMath.degToRad + .pi],
            "speedVar": [AgentMath.clamp01(ctx.agentNumber("speedVariance", 0.3))],
            "angleVarRad": [min(max(ctx.agentNumber("angleVariance", 30), 0), 180) * AgentMath.degToRad],
            "randomness": [AgentMath.clamp01(ctx.agentNumber("randomness", 0.25))],
            "twinkle": [AgentMath.clamp01(ctx.agentNumber("twinkle", 0.5))],
            "softness": [AgentMath.clamp01(ctx.agentNumber("softness", 0.1))],
            "bodyR": [bodyR],
            "cursorX": [f.pointerX * f.aspect], "cursorY": [f.pointerY],
            "cursorRadSq": [cursorRadius * cursorRadius],
            "cursorForce": [AgentMath.clamp01(ctx.agentNumber("cursorStrength", 0)) * Self.cursorForceK],
            "dragMul": [AgentMath.expDecay(Self.cursorDrag, f.dt)],
        ])
        return system.frame(count: count)
    }
}

// MARK: - MagneticFilings (shaders/MagneticFilings)

final class MagneticFilingsSimulation: AgentSimulation {
    private static let maxFilings = 12288
    private static let res = 1024
    private static let alignBase: Float = 45
    private static let restK: Float = 6
    private static let dampMin: Float = 3
    private static let dampSpan: Float = 9
    private static let omegaRef: Float = 6
    private static let agitCool: Float = 1
    private static let homeK: Float = 2.5
    private static let pullK: Float = 0.25
    private static let overscan: Float = 0.14

    let system: AgentSystem
    private let motionAxis = AgentMotionAxis(smoothing: 0.1, teleport: 0.25)

    init(_ ctx: ComputeContext) throws {
        system = try AgentSystem(context: ctx, config: .init(
            maxAgents: Self.maxFilings, countCap: Self.maxFilings,
            outputWidth: Self.res, outputHeight: Self.res,
            pipelines: [
                "init": .init(kernel: 0, threads: .max),
                "update": .init(kernel: 1, threads: .agents),
                "splat": .init(kernel: 2, threads: .agents),
                "resolve": .init(kernel: 3, threads: .fixed(Self.res, Self.res)),
            ],
            program: ["update", "splat", "resolve"], initStep: "init"))
    }

    func frame(_ ctx: ComputeContext) -> [AgentSystem.Dispatch]? {
        let f = AgentFrame(ctx)
        let domainX = max(f.aspect, 0.01)
        let count = system.resolveCount(ctx.agentNumber("count", 5000))
        let grid = AgentMath.fitJitteredGrid(count: count, domainX: domainX, overscan: Self.overscan)
        let cursorX = f.pointerX * f.aspect
        let cursorY = f.pointerY
        let axis = motionAxis.update(cursorX, cursorY)
        let fieldType: Float = (ctx.string("fieldType") ?? "dipole") == "radial" ? 1 : 0
        let restStr = ctx.string("restOrientation") ?? "random"
        let restMode: Float = restStr == "horizontal" ? 1 : restStr == "vertical" ? 2 : 0
        let reach = ctx.agentNumber("reach", 0.35)
        let response = AgentMath.clamp01(ctx.agentNumber("response", 0.5))
        let bodyR = min(max(ctx.agentNumber("size", 1), 0.5), 3) * 1.7 / AgentMath.sizeRefRes

        system.writeParams(ctx, [
            "colA": ctx.agentColor("colorA", fallback: SIMD4(0.522, 0.573, 0.639, 1)),
            "colB": ctx.agentColor("colorB", fallback: SIMD4(1, 0.616, 0.361, 1)),
            "count": [Float(count)],
            "dt": [f.dt], "aspect": [f.aspect], "domainX": [domainX],
            "cursorX": [cursorX], "cursorY": [cursorY], "axisX": [axis.x], "axisY": [axis.y],
            "fieldType": [fieldType], "restMode": [restMode],
            "strength": [ctx.agentNumber("strength", 1)], "reachSq": [reach * reach],
            "alignK": [Self.alignBase], "damping": [Self.dampMin + response * Self.dampSpan],
            "restK": [Self.restK], "pullK": [Self.pullK], "homeK": [Self.homeK],
            "omegaRef": [Self.omegaRef], "agitCool": [Self.agitCool],
            "gridCols": [Float(grid.cols)], "cellW": [grid.cellW], "cellH": [grid.cellH], "jitter": [0.85],
            "bodyR": [bodyR],
        ])
        return system.frame(count: count)
    }
}

// MARK: - ParticleField (shaders/ParticleField)

final class ParticleFieldSimulation: AgentSimulation {
    private static let gridDimMax = 256
    private static let maxParticles = gridDimMax * gridDimMax
    private static let countMax = 40000
    private static let outMax = 1024
    private static let drag: Float = 4.2
    private static let cursorForceK: Float = 10
    private static let cursorZForceK: Float = 4

    private(set) var system: AgentSystem
    private var outW: Int
    private var outH: Int
    private var aspect0: Float
    private var localTime: Double = 0
    private var frameIdx = 0

    init(_ ctx: ComputeContext) throws {
        let size = Self.outputSize(ctx)
        outW = size.w
        outH = size.h
        aspect0 = size.aspect
        system = try Self.makeSystem(ctx, outW, outH)
    }

    /// Upstream `bake`: the output matches the frame aspect (square texels) within OUT_MAX.
    private static func outputSize(_ ctx: ComputeContext) -> (w: Int, h: Int, aspect: Float) {
        let aspect0: Float = ctx.height > 0 ? Float(ctx.width) / Float(ctx.height) : 1
        var w = outMax
        var h = outMax
        if aspect0 >= 1 { h = max(AgentMath.jsRound(Double(outMax) / Double(aspect0)), 1) }
        else { w = max(AgentMath.jsRound(Double(outMax) * Double(aspect0)), 1) }
        return (w, h, aspect0)
    }

    private static func makeSystem(_ ctx: ComputeContext, _ w: Int, _ h: Int) throws -> AgentSystem {
        try AgentSystem(context: ctx, config: .init(
            maxAgents: maxParticles, countCap: countMax,
            outputWidth: w, outputHeight: h,
            pipelines: [
                "sim": .init(kernel: 0, threads: .grid),
                "splat": .init(kernel: 1, threads: .grid),
                "resolve": .init(kernel: 2, threads: .fixed(w, h)),
            ],
            program: ["sim", "splat", "resolve"], initStep: nil))
    }

    func frame(_ ctx: ComputeContext) throws -> [AgentSystem.Dispatch]? {
        // The output extent is decided per composition upstream; a resize here re-bakes it.
        let size = Self.outputSize(ctx)
        if size.w != outW || size.h != outH {
            outW = size.w
            outH = size.h
            aspect0 = size.aspect
            system = try Self.makeSystem(ctx, outW, outH)
            localTime = 0
            frameIdx = 0
        }
        // `src` is the child RTT (premultiplied), bound late like upstream's `bindInputs`.
        guard let src = ctx.rttTextures["rtt_0"] ?? ctx.childTexture else { return nil }
        system.bindExternal("src", src)

        let f = AgentFrame(ctx, fallbackAspect: aspect0)
        localTime += Double(f.dt)
        let count = system.resolveCount(ctx.agentNumber("count", 15000), min: 500)
        let grid = AgentMath.fitIsoGrid(count: count, aspect: f.aspect, min: 8, max: Self.gridDimMax)
        let cursorMode = ctx.string("cursorMode").flatMap { $0.isEmpty ? nil : $0 } ?? "push"
        let cursorSign: Float = cursorMode == "pull" ? -1 : 1
        let cursorStrength: Float = cursorMode == "none" ? 0 : ctx.agentNumber("cursorStrength", 0.5)
        let cursorRadius = ctx.agentNumber("cursorRadius", 0.22)
        let rows = AgentMath.cameraRowsYDown(ctx.agentNumber("rotationX", 0) * AgentMath.degToRad,
                                             ctx.agentNumber("rotationY", 0) * AgentMath.degToRad,
                                             ctx.agentNumber("rotationZ", 0) * AgentMath.degToRad)

        system.writeParams(ctx, [
            "rowX": [rows.rowX.x, rows.rowX.y, rows.rowX.z, 0],
            "rowY": [rows.rowY.x, rows.rowY.y, rows.rowY.z, 0],
            "rowZ": [rows.rowZ.x, rows.rowZ.y, rows.rowZ.z, 0],
            "dt": [f.dt], "time": [Float(localTime)], "snap": [frameIdx == 0 ? 1 : 0],
            "gridW": [Float(grid.w)], "gridH": [Float(grid.h)], "outW": [Float(outW)], "outH": [Float(outH)],
            "depth": [ctx.agentNumber("depth", 0.7)],
            "dragMul": [AgentMath.expDecay(Self.drag, f.dt)],
            "wobbleAmp": [ctx.agentNumber("wobble", 0.35)],
            "depthShading": [AgentMath.clamp01(ctx.agentNumber("depthShading", 0.6))],
            // The isotropic pitch: GW and GH clamp independently, so take the tighter one.
            "spacing": [min(Float(outW) / Float(grid.w), Float(outH) / Float(grid.h))],
            "particleSize": [ctx.agentNumber("particleSize", 1.3)],
            "aspect": [f.aspect],
            "zoom": [min(max(ctx.agentNumber("zoom", 1), 0.05), 10)],
            "transX": [ctx.agentNumber("offsetX", 0)], "transY": [ctx.agentNumber("offsetY", 0)],
            "pointerX": [f.pointerX], "pointerY": [f.pointerY],
            "cursorForce": [cursorSign * cursorStrength * Self.cursorForceK],
            "cursorZForce": [cursorSign * cursorStrength * Self.cursorZForceK],
            "cursorRadSq": [cursorRadius * cursorRadius],
        ])
        frameIdx += 1
        return system.frame(count: count, grid: (grid.w, grid.h))
    }
}

// MARK: - ParticleFlow (shaders/ParticleFlow)

/// Particles advected by a 256² Stable-Fluids velocity field. The fluid kernels (force stamp,
/// curl, vorticity + ambient breeze, divergence, Jacobi, gradient subtract, advect, copy) run
/// through the same harness; the solved velocity texture is bound as both `velOutTex` (written by
/// copyVel) and `velTex` (read by the particle integrator).
final class ParticleFlowSimulation: AgentSimulation {
    private static let n = 256
    private static let maxParticles = 16384
    private static let res = 1024
    private static let jacobiIters = 10
    private static let impulseK: Float = 0.16
    private static let maxSteps = 16
    private static let forceRadiusGrid: Float = 0.16 * Float(n)
    private static let velFadeMax: Float = 4
    private static let velFadeMin: Float = 0.05
    private static let ambientFreq: Float = 2.4
    private static let ambientDrift: Double = 0.09
    private static let speedNorm: Float = 0.35
    private static let warmupFrames = 3

    // Kernel indices (pipeline creation order upstream: force, local vorticity, then the solver set,
    // then the particle pipelines).
    private static let kForce = 0
    private static let kVorticity = 1
    private static let kCurl = 2
    private static let kDivergence = 4
    private static let kJacobi = 5
    private static let kGradSubtract = 6
    private static let kAdvectVel = 7
    private static let kCopyVel = 8
    private static let kInit = 9

    let system: AgentSystem
    private let flowName: String
    private let splatName: String
    private let pointer = AgentPointerTracker()
    private let idle = AgentIdleGate(warmupFrames: warmupFrames + 1)
    private var pointerSeen = false
    private var ambientTime: Double = 0
    private var initialized = false

    init(_ ctx: ComputeContext) throws {
        system = try AgentSystem(context: ctx, config: .init(
            maxAgents: Self.maxParticles, countCap: Self.maxParticles,
            outputWidth: Self.res, outputHeight: Self.res,
            pipelines: [
                // Dispatched manually on the first live frame (see `frame`), not via the init latch.
                "init": .init(kernel: Self.kInit, threads: .max),
                "integrate": .init(kernel: 10, threads: .agents),
                "splat": .init(kernel: 11, threads: .agents),
                "resolve": .init(kernel: 12, threads: .fixed(Self.res, Self.res)),
            ],
            program: ["integrate", "splat", "resolve"], initStep: nil))
        guard let vel = ctx.makeTexture(width: Self.n, height: Self.n, label: "ParticleFlow velTex") else { throw ShaderEngineError.noMetalDevice }
        system.bindExternal("velOutTex", vel)
        system.bindExternal("velTex", vel)
        flowName = system.uniformName(ofType: "FlowParams") ?? "params"
        splatName = system.uniformName(ofType: "SplatParams") ?? "sparams"
    }

    func frame(_ ctx: ComputeContext) -> [AgentSystem.Dispatch]? {
        let dt = min(ctx.frame.deltaTime, 0.033)
        if dt < 0.001 { return nil }
        let aspect: Float = ctx.height > 0 ? Float(ctx.width) / Float(ctx.height) : 16.0 / 9.0
        let domainX = max(aspect, 0.01)

        let forceVal = ctx.agentNumber("force", 1)
        let swirl = ctx.agentNumber("swirl", 25)
        let ambient = AgentMath.clamp01(ctx.agentNumber("ambient", 0.15))
        let momentum = AgentMath.clamp01(ctx.agentNumber("momentum", 0.6))
        let advect = ctx.agentNumber("speed", 1)
        let count = system.resolveCount(ctx.agentNumber("count", 6000), min: 100)
        let bodyR = min(max(ctx.agentNumber("size", 1.2), 0.3), 3) * 1.3 / AgentMath.sizeRefRes

        // The tracker's teleport guard keeps a pointer jump from plowing a wake across the field.
        pointerSeen = pointerSeen || ctx.frame.pointerActive
        let ptr = pointer.update(ctx.frame.pointer, seen: pointerSeen, dt: dt)
        let active = ptr.moving || ambient > 0.001
        if active { idle.markActive() }
        ambientTime += Double(dt) * Self.ambientDrift

        // Idle-freeze: once the field has settled and nothing drives it, stop dispatching.
        if initialized && idle.shouldSkip(2 + momentum * 13, driving: active) { return nil }
        idle.tickFrame(dt)

        let velFade = Self.velFadeMax * pow(Self.velFadeMin / Self.velFadeMax, momentum)
        system.write(ctx, flowName, [
            "dt": [dt], "curlStrength": [swirl], "velFade": [velFade],
            "ambient": [ambient], "ambientTime": [Float(ambientTime)], "ambientFreq": [Self.ambientFreq],
        ])
        system.writeParams(ctx, [
            "colA": ctx.agentColor("colorA", fallback: SIMD4(0.56, 0.77, 1, 1)),
            "colB": ctx.agentColor("colorB", fallback: SIMD4(1, 0.85, 0.56, 1)),
            "dt": [dt], "aspect": [domainX],
            "trails": [AgentMath.clamp01(ctx.agentNumber("trails", 0)) * 0.92],
            "bodyR": [bodyR], "speedNorm": [Self.speedNorm], "advect": [advect],
        ])

        let grid = SIMD3<UInt32>(UInt32(Self.n), UInt32(Self.n), 1)
        var nodes: [AgentSystem.Dispatch] = []
        if !initialized {
            initialized = true
            nodes.append(.init(kernel: Self.kInit, threads: SIMD3(UInt32(Self.maxParticles), 1, 1)))
        }

        // Cursor force: a ribbon of velocity-proportional impulse stamps along the drag path.
        if ptr.moving {
            let velX = ptr.velX * Float(Self.n) * forceVal * Self.impulseK
            let velY = ptr.velY * Float(Self.n) * forceVal * Self.impulseK
            let stamps = AgentStampRibbon.stamps(fromX: ptr.prevX, fromY: ptr.prevY, dx: ptr.dx, dy: ptr.dy,
                                                 dragDist: ptr.dragDist,
                                                 stepSize: max(0.004, (Self.forceRadiusGrid / Float(Self.n)) * 0.6),
                                                 maxSteps: Self.maxSteps, scale: Float(Self.n))
            for p in stamps {
                let bytes = system.pack(ctx, splatName, ["posX": [p.x], "posY": [p.y], "velX": [velX], "velY": [velY], "radius": [Self.forceRadiusGrid]])
                nodes.append(.init(kernel: Self.kForce, threads: grid, uniforms: [splatName: bytes]))
            }
        }

        // solveSteps: curl → vorticity (with the ambient breeze) → divergence → J× jacobi →
        // gradSubtract → advectVel → copyVel (publishes velTex).
        for k in [Self.kCurl, Self.kVorticity, Self.kDivergence] { nodes.append(.init(kernel: k, threads: grid)) }
        for _ in 0..<Self.jacobiIters { nodes.append(.init(kernel: Self.kJacobi, threads: grid)) }
        for k in [Self.kGradSubtract, Self.kAdvectVel, Self.kCopyVel] { nodes.append(.init(kernel: k, threads: grid)) }
        nodes += system.frame(count: count)
        return nodes
    }
}

// MARK: - Particles (shaders/Particles)

/// The generated kernels bake the default shape (`sphere3D` through `createAnalytic3dSdfSetup`), so
/// the containment field is always a sphere: its radius and rotation come from the `shape` config.
/// Other shape types reuse the sphere with their `radius` (or `size`) sub-prop.
final class ParticlesSimulation: AgentSimulation {
    private static let maxParticles = 16000
    private static let dgrid = 32
    private static let domain: Float = 1
    private static let outRes = 1024
    private static let maxSpeed: Float = 3
    private static let sizeScale = Float(outRes) / AgentMath.sizeRefRes
    private static let defaultShape = "{\"type\":\"sphere3D\",\"radius\":0.35}"

    let system: AgentSystem
    private let marchName: String?
    private var time: Double = 0
    private var frameIdx = 0
    private var prevRot: SIMD3<Float>?
    private var shapeJSON = ""
    private var shapeConfig: [String: Any] = [:]

    init(_ ctx: ComputeContext) throws {
        let cells = Self.dgrid * Self.dgrid * Self.dgrid
        system = try AgentSystem(context: ctx, config: .init(
            maxAgents: Self.maxParticles, countCap: Self.maxParticles,
            outputWidth: Self.outRes, outputHeight: Self.outRes,
            pipelines: [
                "init": .init(kernel: 0, threads: .max),
                "clearDensity": .init(kernel: 1, threads: .fixed(cells, 1)),
                "density": .init(kernel: 2, threads: .agents),
                "update": .init(kernel: 3, threads: .agents),
                "splat": .init(kernel: 4, threads: .agents),
                "resolve": .init(kernel: 5, threads: .fixed(Self.outRes, Self.outRes)),
            ],
            program: ["clearDensity", "density", "update", "splat", "resolve"], initStep: "init"))
        marchName = system.uniformName(ofType: "MarchParams")
    }

    /// The shape config (a JSON string prop), re-parsed only when it changes.
    private func config(_ ctx: ComputeContext) -> [String: Any] {
        let raw = ctx.string("shape") ?? Self.defaultShape
        if raw != shapeJSON {
            shapeJSON = raw
            if let data = raw.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                shapeConfig = obj
            } else {
                shapeConfig = [:]
            }
        }
        return shapeConfig
    }

    /// `resolveShapeSubProp` for plain numbers. Auto-animate / mouse driver objects resolve to the fallback.
    private static func sub(_ value: Any?, _ fallback: Float) -> Float {
        if let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { return n.floatValue }
        return fallback
    }

    /// JavaScript `a ?? b ?? …` over config keys.
    private static func first(_ cfg: [String: Any], _ keys: [String]) -> Any? {
        for k in keys { if let v = cfg[k], !(v is NSNull) { return v } }
        return nil
    }

    func frame(_ ctx: ComputeContext) -> [AgentSystem.Dispatch]? {
        // Square shape-local domain: an unknown canvas size means aspect 1.
        let f = AgentFrame(ctx, fallbackAspect: 1)
        time += Double(f.dt)
        let center = ctx.agentUniformField("n_x.center") ?? [0.5, 0.5]
        let centerX = center[0]
        let centerYv = 1 - center[1]
        let scale = max(ctx.agentNumber("scale", 1), 0.01)
        let rotRad = ctx.agentNumber("rotation", 0) * AgentMath.degToRad
        let rotC = cos(rotRad)
        let rotS = sin(rotRad)
        let cursor = AgentMath.pointerToShapeLocal(pointer: SIMD2(f.pointerX, f.pointerY), center: SIMD2(centerX, centerYv),
                                                   scale: scale, rotC: rotC, rotS: rotS, aspect: f.aspect)
        // Gravity is screen-down; rotate it into shape space (y up).
        let gravMag = ctx.agentNumber("gravity", 0) * 1.2
        let cfg = config(ctx)
        let halfDepth = max(ctx.agentNumber("depth", 0.18), 0.01) * 0.5
        let saRotation = Self.sub(cfg["rotation"], 0)

        // Shape-rotation rate → entrainment omega (the 3D shape path).
        let next = SIMD3(Self.sub(cfg["rotX"], 0), Self.sub(cfg["rotY"], 0), Self.sub(cfg["rotZ"], 0)) * AgentMath.degToRad
        let om = AgentMath.omegaFromRotationDeltas(prevRot, next, dt: f.dt) ?? SIMD3<Float>(0, 0, 0)
        prevRot = next
        let ent = AgentMath.entrainmentFromOmega(om, cap: 10, gainRate: 2.5, gainMax: 5)

        let damping = ctx.agentNumber("damping", 0.4)
        let mouseRadius = ctx.agentNumber("mouseRadius", 0.22)
        let gridOff = AgentMath.r3SubCellOffset(frameIdx, cell: 2 * Self.domain / Float(Self.dgrid))

        system.writeParams(ctx, [
            "colA": ctx.agentColor("colorA", fallback: SIMD4(1, 1, 1, 1)),
            "colB": ctx.agentColor("colorB", fallback: SIMD4(1, 1, 1, 1)),
            "dt": [f.dt], "time": [Float(time)],
            "spread": [ctx.agentNumber("spread", 1)],
            "agitation": [ctx.agentNumber("agitation", 0.12)],
            "dragMul": [AgentMath.expDecay(2.2 + damping * 6, f.dt)],
            "gravX": [rotS * gravMag], "gravY": [-(rotC * gravMag)], "halfDepth": [halfDepth],
            "cursorX": [cursor.x], "cursorY": [cursor.y],
            "cursorForce": [ctx.agentNumber("mouseInfluence", 1.2) * 3],
            "cursorRadSq": [mouseRadius * mouseRadius],
            "saRadius": [Self.sub(Self.first(cfg, ["radius", "width", "bottomWidth"]), 0.35)],
            "saSides": [Self.sub(cfg["sides"], 6)],
            "saRounding": [Self.sub(cfg["rounding"], 0)],
            "saInnerRatio": [Self.sub(Self.first(cfg, ["innerRatio", "thickness", "spread", "topWidth", "topRatio"]), 0.4)],
            "saRotation": [saRotation],
            "saHeight": [Self.sub(cfg["height"], 0.25)],
            "saOffset": [Self.sub(Self.first(cfg, ["offset", "skew"]), 0.2)],
            "saAperture": [Self.sub(cfg["aperture"], 270)],
            "centerX": [centerX], "centerYv": [centerYv], "scale": [scale], "rotC": [rotC], "rotS": [rotS], "aspect": [f.aspect],
            "size": [ctx.agentNumber("size", 2.2) * Self.sizeScale],
            "exposure": [ctx.agentNumber("exposure", 1)],
            "softness": [AgentMath.clamp01(ctx.agentNumber("softness", 0.5))],
            "speedColorK": [2 / Self.maxSpeed],
            "omegaX": [ent.omega.x], "omegaY": [ent.omega.y], "omegaZ": [ent.omega.z], "entrain": [ent.entrain],
            "gridOffX": [gridOff.x], "gridOffY": [gridOff.y], "gridOffZ": [gridOff.z],
        ])
        frameIdx += 1

        // createAnalytic3dSdfSetup.update for the baked sphere: radius (pA) and the ZXY rotation.
        // The other MarchParams fields only drive raymarching, which these kernels never do.
        if let marchName {
            let radius = Self.sub(Self.first(cfg, ["radius", "size"]), 0.35)
            system.write(ctx, marchName, [
                "rot.cx": [cos(next.x)], "rot.sx": [sin(next.x)],
                "rot.cy": [cos(next.y)], "rot.sy": [sin(next.y)],
                "rot.cz": [cos(next.z)], "rot.sz": [sin(next.z)],
                "pA": [radius], "pB": [0.3], "pC": [0.3], "pD": [0],
            ])
        }
        return system.frame(count: system.resolveCount(ctx.agentNumber("count", 4000)))
    }
}
#endif
