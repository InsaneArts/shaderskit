#if canImport(Metal)
import Foundation
import Metal
import simd

/// PixelThrow (shaders/PixelThrow): the CPU member of the grid family (`hostGridProgram` +
/// `hostFieldTexture`, std/sim/grids.ts). A 128² throw field of UV displacements is advected,
/// decayed, brushed by the cursor velocity and tanh-saturated on the CPU each frame, then uploaded
/// as the rgba16float texture the fragment samples as `media_1`.
///
/// Upstream runs this from the fragment's `onBeforeRender`, not a compute hook, and the descriptor
/// has no compute flag, so the renderer never runs a `ComputeProgram` for it. It is a
/// `MediaProgram` instead (media programs run before every pass and may bind `media_N` keys).
final class GridPixelThrowProgram: MediaProgram {
    static let shaderNames = ["PixelThrow"]
    static let grid = 128

    private var flow = [Float](repeating: 0, count: grid * grid * 2)
    private var temp = [Float](repeating: 0, count: grid * grid * 2)
    private var halves = [UInt16](repeating: 0, count: grid * grid * 4)
    private let field: MTLTexture
    private var needsZero = true

    private var prevX: Float = 0.5, prevY: Float = 0.5
    private var velX: Float = 0, velY: Float = 0
    private var speed: Float = 0
    private var maxThrow: Float = 0.125

    init(context ctx: MediaContext) throws {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Self.grid, height: Self.grid, mipmapped: false)
        d.usage = [.shaderRead, .renderTarget]
        d.storageMode = .private
        guard let t = ctx.device.device.makeTexture(descriptor: d) else { throw ShaderEngineError.noMetalDevice }
        t.label = "pixelthrow-flow"
        field = t
    }

    /// Bilinear tap of the flow field; zero outside the grid.
    private func sampleFlow(_ gx: Float, _ gy: Float, _ ch: Int) -> Float {
        let G = Self.grid
        let x0f = gx.rounded(.down), y0f = gy.rounded(.down)
        guard x0f >= 0, y0f >= 0, x0f + 1 < Float(G), y0f + 1 < Float(G) else { return 0 }
        let x0 = Int(x0f), y0 = Int(y0f)
        let fx = gx - x0f, fy = gy - y0f
        let i00 = (y0 * G + x0) * 2 + ch
        let i01 = (y0 * G + x0 + 1) * 2 + ch
        let i10 = ((y0 + 1) * G + x0) * 2 + ch
        let i11 = ((y0 + 1) * G + x0 + 1) * 2 + ch
        return flow[i00] * (1 - fx) * (1 - fy) + flow[i01] * fx * (1 - fy) + flow[i10] * (1 - fx) * fy + flow[i11] * fx * fy
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        let out = MediaOutputs(textures: ["media_1": field])
        if needsZero {
            GridKit.zero(textures: [field], cb: ctx.commandBuffer)
            needsZero = false
        }
        let G = Self.grid
        let Gf = Float(G)
        let props = ctx.props
        // Upstream steps on a clamped wall-clock delta; the frame delta stands in for it.
        let dt = min(ctx.frame.deltaTime, 0.016)
        let pointer = ctx.frame.pointer
        // dtGuard
        if dt <= 0 { return out }
        // cursorVelocity
        velX = velX * 0.8 + (pointer.x - prevX) / dt * 0.2
        velY = velY * 0.8 + (pointer.y - prevY) / dt * 0.2
        speed = (velX * velX + velY * velY).squareRoot()
        // advect+decay
        let friction = GridKit.num(props, "friction", 0.3)
        let momentum = GridKit.num(props, "momentum", 0.5)
        maxThrow = GridKit.num(props, "strength", 0.25) * 0.5
        let decay = max(0, 1 - friction * dt * 4)
        let advect = momentum * dt * 12
        for i in 0..<G {
            for j in 0..<G {
                let idx = (i * G + j) * 2
                let srcX = Float(j) - flow[idx] * Gf * advect
                let srcY = Float(i) - flow[idx + 1] * Gf * advect
                temp[idx] = sampleFlow(srcX, srcY, 0) * decay
                temp[idx + 1] = sampleFlow(srcX, srcY, 1) * decay
            }
        }
        // inject(brush): Gaussian shifted to reach exactly zero at the brush edge.
        if speed > 0.02 {
            let aspect = max(0.0001, Float(ctx.width) / Float(max(1, ctx.height)))
            let r = max(0.001, GridKit.num(props, "radius", 0.2))
            let r2 = r * r
            let edge = exp(Float(-1))
            let invEdge = 1 / (1 - edge)
            let minI = max(0, Int(((pointer.y - r) * Gf).rounded(.down)))
            let maxI = min(G - 1, Int(((pointer.y + r) * Gf).rounded(.up)))
            let minJ = max(0, Int(((pointer.x - r) * Gf).rounded(.down)))
            let maxJ = min(G - 1, Int(((pointer.x + r) * Gf).rounded(.up)))
            if minI <= maxI && minJ <= maxJ {
                for i in minI...maxI {
                    for j in minJ...maxJ {
                        let cellX = (Float(j) + 0.5) / Gf
                        let cellY = (Float(i) + 0.5) / Gf
                        let dx = aspect >= 1 ? (cellX - pointer.x) * aspect : cellX - pointer.x
                        let dy = aspect >= 1 ? cellY - pointer.y : (cellY - pointer.y) / aspect
                        let distSq = dx * dx + dy * dy
                        if distSq > r2 { continue }
                        let influence = (exp(-distSq / r2) - edge) * invEdge
                        let idx = (i * G + j) * 2
                        temp[idx] += velX * influence * dt * 4
                        temp[idx + 1] += velY * influence * dt * 4
                    }
                }
            }
        }
        // saturate(tanh): soft-saturate the displacement magnitude.
        for k in 0..<(G * G) {
            let fx = temp[k * 2], fy = temp[k * 2 + 1]
            let len = (fx * fx + fy * fy).squareRoot()
            if len > 1e-6 {
                let s = (maxThrow * tanh(len / maxThrow)) / len
                temp[k * 2] = fx * s
                temp[k * 2 + 1] = fy * s
            }
        }
        // publish(halfFloat): RG displacement in the rgba16float texture (b/a unused).
        (flow, temp) = (temp, flow)
        for k in 0..<(G * G) {
            halves[k * 4] = GridKit.halfBits(flow[k * 2])
            halves[k * 4 + 1] = GridKit.halfBits(flow[k * 2 + 1])
        }
        halves.withUnsafeBytes { GridKit.upload($0, bytesPerRow: G * 8, to: field, device: ctx.device.device, cb: ctx.commandBuffer) }
        prevX = pointer.x
        prevY = pointer.y
        return out
    }
}
#endif
