#if canImport(Metal)
import Foundation
import Metal

/// CursorTrail (shaders/CursorTrail `polylineRecorder`): records the pointer path as up to 64
/// points (x, y, age, signed width) — committed anchors plus a live head, Chaikin-relaxed joints,
/// pen-pressure width from the smoothed pointer speed, ageing with front-culling — and packs it
/// into the 64×1 rgba16float texture the capsule-chain scan reads as `media_0`.
final class CursorTrailHostProgram: MediaProgram {
    static let shaderNames = ["CursorTrail"]
    static let maxPoints = 64
    static let widthMin: Float = 0.2
    static let speedFull: Float = 1.5
    private static let halfOne = GridKit.halfBits(1)

    private struct TrailPoint { var x: Float, y: Float, age: Float, link: Float, width: Float }

    private var pts: [TrailPoint] = []
    private var texData = [UInt16](repeating: 0, count: maxPoints * 4)
    private let dataTex: MTLTexture
    private var needsInitialUpload = true
    // Teleport guard disabled on purpose upstream: any jump paints a straight stroke.
    private var tracker = GridKit.PointerTracker(teleportGuard: .infinity, minDrag: 0.001)
    private var headDist: Float = 0
    private var wasActive = false

    init(context ctx: MediaContext) throws {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Self.maxPoints, height: 1, mipmapped: false)
        d.usage = [.shaderRead]
        d.storageMode = .private
        guard let t = ctx.device.device.makeTexture(descriptor: d) else { throw ShaderEngineError.noMetalDevice }
        t.label = "cursortrail-points"
        dataTex = t
        for i in 0..<Self.maxPoints { texData[i * 4 + 2] = Self.halfOne } // all slots dead
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        let out = MediaOutputs(textures: ["media_0": dataTex])
        let rawDt = max(0, ctx.frame.deltaTime)
        let dt = min(rawDt, 0.1)
        let length = ctx.scalar("length")
        let drawRadius = ctx.scalar("radius") * 0.1
        let curW = max(1, Float(ctx.frame.logicalSize.x).rounded())
        let curH = max(1, Float(ctx.frame.logicalSize.y).rounded())
        let aspect = curW / curH
        let move = tracker.update(ctx.frame.pointer, dt: dt)

        // Age + front-cull (ages are oldest-first).
        let ageRate = min(rawDt, 0.25) / max(0.1, length)
        for i in pts.indices { pts[i].age = min(1, pts[i].age + ageRate) }
        while let first = pts.first, first.age >= 1 { pts.removeFirst() }

        if move.dragDist > 0.001 {
            let stepDist = ((move.dx * aspect) * (move.dx * aspect) + move.dy * move.dy).squareRoot()
            let widthNow = min(1, max(Self.widthMin, (move.smoothSpeed / Self.speedFull).squareRoot()))
            if pts.isEmpty {
                pts.append(TrailPoint(x: move.prevX, y: move.prevY, age: 0, link: 0, width: widthNow)) // stroke-start anchor
                pts.append(TrailPoint(x: move.x, y: move.y, age: 0, link: 1, width: widthNow)) // live head
                headDist = stepDist
            } else {
                let h = pts.count - 1
                pts[h].x = move.x
                pts[h].y = move.y
                pts[h].age = 0
                pts[h].width = widthNow
                headDist += stepDist
                if headDist >= max(0.006, drawRadius * 0.5) {
                    // Chaikin-style relax of the joint one back.
                    let n = pts.count
                    if n >= 3 && pts[n - 2].link == 1 {
                        pts[n - 2].x = 0.25 * pts[n - 3].x + 0.5 * pts[n - 2].x + 0.25 * pts[n - 1].x
                        pts[n - 2].y = 0.25 * pts[n - 3].y + 0.5 * pts[n - 2].y + 0.25 * pts[n - 1].y
                    }
                    pts.append(TrailPoint(x: move.x, y: move.y, age: 0, link: 1, width: widthNow))
                    headDist = 0
                }
            }
            while pts.count > Self.maxPoints - 1 { pts.removeFirst() } // reserve one slot for the head duplicate
        }

        // Upload while something is alive, plus one final all-dead frame (and the initial dead state:
        // Metal does not initialise textures).
        let active = !pts.isEmpty
        if active || wasActive || needsInitialUpload {
            needsInitialUpload = false
            let count = pts.isEmpty ? 0 : pts.count + 1
            for i in 0..<Self.maxPoints {
                let base = i * 4
                if i < count {
                    let p = pts[min(i, pts.count - 1)]
                    texData[base] = GridKit.halfBits(p.x)
                    texData[base + 1] = GridKit.halfBits(p.y)
                    texData[base + 2] = GridKit.halfBits(p.age)
                    texData[base + 3] = GridKit.halfBits((i == pts.count || p.link == 1) ? p.width : -p.width)
                } else {
                    texData[base] = 0
                    texData[base + 1] = 0
                    texData[base + 2] = Self.halfOne
                    texData[base + 3] = 0
                }
            }
            texData.withUnsafeBytes { GridKit.upload($0, bytesPerRow: Self.maxPoints * 8, to: dataTex, device: ctx.device.device, cb: ctx.commandBuffer) }
        }
        wasActive = active
        return out
    }
}
#endif
