#if canImport(Metal)
import Foundation
import Metal
import simd

/// Shatter (shaders/Shatter, `voronoiRegionField` in std/effects/fracture.ts): the GPU Voronoi
/// region field (nearest + second-nearest cell per pixel, 1024², re-dispatched only on a seed
/// change) as `compute_0`, plus the per-frame CPU shard physics (`shardPhysics`) published as the
/// 64×1 r16float `shardDataTexture` the fragment reads as `media_1`. Upstream runs the physics in
/// the fragment's `onBeforeRender`; here it runs in the same per-frame hook, before the final pass.
final class GridShatterProgram: ComputeProgram {
    static let shaderNames = ["Shatter"]

    private static let shardCount = 16
    private static let voronoiSize = 1024
    private static let dataWidth = shardCount * 4
    private static let friction: Double = 1

    private let voronoi: ComputeKernelDescriptor
    private let cellPos: MTLBuffer
    private let field: MTLTexture
    private let dataTex: MTLTexture
    private var needsZero = true

    // voronoiRegionField state
    private var fieldSeed: Float
    private var needsDispatch = true

    // shardPhysics state (Float32Array storage upstream)
    private var physicsSeed: Float
    private var cellData = [Float](repeating: 0, count: shardCount * 4)
    private var displacement = [Float](repeating: 0, count: shardCount * 4)
    private var prevX: Float = 0.5, prevY: Float = 0.5

    init(context ctx: ComputeContext) throws {
        voronoi = try GridKit.kernel(ctx, 0)
        guard let b = ctx.makeBuffer(length: Self.shardCount * 2 * 4, label: "Shatter sites") else { throw ShaderEngineError.noMetalDevice }
        cellPos = b
        field = try GridKit.texture(ctx, Self.voronoiSize, Self.voronoiSize, label: "Shatter voronoi")
        dataTex = try GridKit.texture(ctx, Self.dataWidth, 1, .r16Float, label: "Shatter cells")
        fieldSeed = GridKit.num(ctx, "seed", 2)
        physicsSeed = fieldSeed
        writeSites(fieldSeed)
        generateCells(physicsSeed)
    }

    /// `seededRandom` — evaluated in double precision like the JS original (sin·10000 needs it).
    static func seededRandom(_ seed: Double) -> Double {
        let x = sin(seed) * 10000
        return x - x.rounded(.down)
    }

    /// `shardSites`: the Voronoi cell centres for a seed, [posX, posY] per shard.
    static func sites(_ seed: Float) -> [Float] {
        var p = [Float](repeating: 0, count: shardCount * 2)
        let s = Double(seed)
        for i in 0..<shardCount {
            p[i * 2] = Float(seededRandom(s + Double(i * 2)))
            p[i * 2 + 1] = Float(seededRandom(s + Double(i * 2 + 1)))
        }
        return p
    }

    private func writeSites(_ seed: Float) {
        let s = Self.sites(seed)
        _ = s.withUnsafeBytes { memcpy(cellPos.contents(), $0.baseAddress!, $0.count) }
    }

    private func generateCells(_ seed: Float) {
        let sites = Self.sites(seed)
        let s = Double(seed)
        for i in 0..<Self.shardCount {
            cellData[i * 4] = sites[i * 2]
            cellData[i * 4 + 1] = sites[i * 2 + 1]
            cellData[i * 4 + 2] = Float(Self.seededRandom(s + Double(i * 3)))
            cellData[i * 4 + 3] = Float(Self.seededRandom(s + Double(i * 3 + 1)))
        }
    }

    /// `shardPhysics.step`.
    private func stepPhysics(_ ctx: ComputeContext, pointer: SIMD2<Float>, deltaTime: Float, aspect: Float) {
        let dt = Double(min(deltaTime, 0.016))
        let newSeed = GridKit.num(ctx, "seed", 2)
        if newSeed != physicsSeed {
            physicsSeed = newSeed
            generateCells(newSeed)
            for i in displacement.indices { displacement[i] = 0 }
        }
        let intensity = Double(GridKit.num(ctx, "intensity", 4))
        let radius = Double(GridKit.num(ctx, "radius", 0.4))
        let decay = Double(GridKit.num(ctx, "decay", 1))
        let px = Double(pointer.x), py = Double(pointer.y)
        var velX = dt > 0 ? (px - Double(prevX)) / dt : 0
        var velY = dt > 0 ? (py - Double(prevY)) / dt : 0
        var speed = (velX * velX + velY * velY).squareRoot()
        let maxVelocity = 5 + intensity * 2
        if speed > maxVelocity {
            let scale = maxVelocity / speed
            velX *= scale
            velY *= scale
            speed = maxVelocity
        }
        let a = Double(aspect)
        for i in 0..<Self.shardCount {
            let cellX = Double(cellData[i * 4]), cellY = Double(cellData[i * 4 + 1])
            let randomDirX = Double(cellData[i * 4 + 2]) - 0.5
            let randomDirY = Double(cellData[i * 4 + 3]) - 0.5
            let dx = a >= 1 ? (cellX - px) * a : cellX - px
            let dy = a >= 1 ? cellY - py : (cellY - py) / a
            let dist = (dx * dx + dy * dy).squareRoot()
            let decayFactor = exp(-dt / max(0.01, decay))
            let currentDx = Double(displacement[i * 4]) * decayFactor
            let currentDy = Double(displacement[i * 4 + 1]) * decayFactor
            var velocityDx = 0.0, velocityDy = 0.0
            if dist < radius && speed > 0.01 {
                let influence = max(0, 1 - dist / radius)
                let curve = influence * influence
                let pushForce = curve * speed * intensity * dt * 0.5
                velocityDx = velX * pushForce
                velocityDy = velY * pushForce
                let jitterForce = curve * speed * intensity * dt * 0.1
                velocityDx += randomDirX * jitterForce
                velocityDy += randomDirY * jitterForce
            }
            let lerpFactor = min(1, Self.friction * dt)
            displacement[i * 4] = Float(currentDx + velocityDx * lerpFactor)
            displacement[i * 4 + 1] = Float(currentDy + velocityDy * lerpFactor)
        }
        prevX = pointer.x
        prevY = pointer.y
    }

    func encode(_ ctx: ComputeContext) throws -> ComputeOutputs {
        if needsZero {
            GridKit.zero(textures: [field, dataTex], cb: ctx.commandBuffer)
            needsZero = false
        }
        // shardPhysics → shardDataTexture: [posX, posY, dispX, dispY] per shard as halves.
        stepPhysics(ctx, pointer: ctx.frame.pointer, deltaTime: ctx.frame.deltaTime, aspect: Float(ctx.width) / Float(max(1, ctx.height)))
        var halves = [UInt16](repeating: 0, count: Self.dataWidth)
        for i in 0..<Self.shardCount {
            halves[i * 4] = GridKit.halfBits(cellData[i * 4])
            halves[i * 4 + 1] = GridKit.halfBits(cellData[i * 4 + 1])
            halves[i * 4 + 2] = GridKit.halfBits(displacement[i * 4])
            halves[i * 4 + 3] = GridKit.halfBits(displacement[i * 4 + 1])
        }
        halves.withUnsafeBytes { GridKit.upload($0, bytesPerRow: Self.dataWidth * 2, to: dataTex, device: ctx.device.device, cb: ctx.commandBuffer) }

        let out = ComputeOutputs(textures: ["compute_0": field, "media_1": dataTex])
        // voronoiRegionField: static between seed changes.
        let newSeed = GridKit.num(ctx, "seed", 2)
        if newSeed != fieldSeed {
            fieldSeed = newSeed
            writeSites(newSeed)
            needsDispatch = true
        }
        guard needsDispatch else { return out }
        needsDispatch = false
        guard let enc = ctx.commandBuffer.makeComputeCommandEncoder() else { return out }
        defer { enc.endEncoding() }
        enc.label = "Shatter voronoi"
        try ctx.dispatch(enc, voronoi, threads: SIMD3(UInt32(Self.voronoiSize), UInt32(Self.voronoiSize), 1)) { e in
            GridKit.setBuffer(e, voronoi, "cellPos", cellPos)
            GridKit.setTexture(e, voronoi, "voronoiTex", field)
        }
        return out
    }
}
#endif
