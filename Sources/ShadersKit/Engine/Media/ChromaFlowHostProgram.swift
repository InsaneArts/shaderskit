#if canImport(Metal)
import Foundation
import Metal

/// ChromaFlow (shaders/ChromaFlow `hostGridProgram`): a 128² CPU field (r,g = flow, b = liquid
/// density) stepped each frame — cursor velocity, idle skip, decay + density advection, brush
/// injection — then half-encoded into the rgba16float texture the fragment samples as `media_0`.
/// Upstream steps on a wall-clock delta clamped to 16 ms; the frame delta stands in for it.
final class ChromaFlowHostProgram: MediaProgram {
    static let shaderNames = ["ChromaFlow"]
    static let grid = 128

    private var fieldData = [Float](repeating: 0, count: grid * grid * 4)
    private var tempFieldData = [Float](repeating: 0, count: grid * grid * 4)
    private var texData = [UInt16](repeating: 0, count: grid * grid * 4)
    private let field: MTLTexture
    private var needsZero = true

    private var mouseVelX: Float = 0, mouseVelY: Float = 0
    private var prevX: Float = 0.5, prevY: Float = 0.5
    private var fieldMax: Float = 0
    private var injecting = false
    private var newMax: Float = 0

    init(context ctx: MediaContext) throws {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: Self.grid, height: Self.grid, mipmapped: false)
        d.usage = [.shaderRead, .renderTarget]
        d.storageMode = .private
        guard let t = ctx.device.device.makeTexture(descriptor: d) else { throw ShaderEngineError.noMetalDevice }
        t.label = "chromaflow-field"
        field = t
    }

    func encode(_ ctx: MediaContext) throws -> MediaOutputs {
        let out = MediaOutputs(textures: ["media_0": field])
        if needsZero {
            GridKit.zero(textures: [field], cb: ctx.commandBuffer)
            needsZero = false
        }
        let G = Self.grid
        let dt = min(max(ctx.frame.deltaTime, 0), 0.016)
        let pointer = ctx.frame.pointer

        // cursorVelocity
        let aspect = Float(ctx.width) / Float(max(1, ctx.height))
        let velX: Float = dt > 0 ? (pointer.x - prevX) / dt : 0
        let velY: Float = dt > 0 ? (pointer.y - prevY) / dt : 0
        mouseVelX = mouseVelX * 0.85 + velX * 0.15
        mouseVelY = mouseVelY * 0.85 + velY * 0.15
        prevX = pointer.x
        prevY = pointer.y
        injecting = abs(velX) + abs(velY) > 0.01

        // idleSkip: both fields decay multiplicatively; a settled, still field needs no step.
        if !injecting && fieldMax < 1e-4 { return out }

        // advect+decay
        let intensity = ctx.scalar("intensity")
        let radius = ctx.scalar("radius") * 0.05
        let momentum = ctx.scalar("momentum")
        let flowFadeRate = 1 - dt / max(0.1, 1.0)
        let liquidFadeRate = 1 - dt
        let flowSpeed = momentum * 50 * dt
        newMax = 0
        for i in 0..<G {
            for j in 0..<G {
                let idx = (i * G + j) * 4
                let fx0 = fieldData[idx]
                let fy0 = fieldData[idx + 1]
                tempFieldData[idx] = fx0 * flowFadeRate
                tempFieldData[idx + 1] = fy0 * flowFadeRate
                tempFieldData[idx + 2] = fieldData[idx + 2] * liquidFadeRate
                if abs(fx0) > 0.001 || abs(fy0) > 0.001 {
                    let advectX = Float(j) - fx0 * flowSpeed
                    let advectY = Float(i) - fy0 * flowSpeed
                    let x0f = advectX.rounded(.down), y0f = advectY.rounded(.down)
                    if x0f >= 0 && y0f >= 0 && x0f + 1 < Float(G) && y0f + 1 < Float(G) {
                        let x0 = Int(x0f), y0 = Int(y0f), x1 = x0 + 1, y1 = y0 + 1
                        let fx = advectX - x0f
                        let fy = advectY - y0f
                        let s = fieldData[(y0 * G + x0) * 4 + 2] * (1 - fx) * (1 - fy)
                            + fieldData[(y0 * G + x1) * 4 + 2] * fx * (1 - fy)
                            + fieldData[(y1 * G + x0) * 4 + 2] * (1 - fx) * fy
                            + fieldData[(y1 * G + x1) * 4 + 2] * fx * fy
                        tempFieldData[idx + 2] = s * liquidFadeRate
                    }
                }
                let m = max(abs(tempFieldData[idx]), abs(tempFieldData[idx + 1]), tempFieldData[idx + 2])
                if m > newMax { newMax = m }
            }
        }

        // inject(brush)
        if injecting {
            let speed = (mouseVelX * mouseVelX + mouseVelY * mouseVelY).squareRoot()
            let speedScale = min(speed * speed * 20, 1.0)
            let effectiveRadius = radius * speedScale
            let maxDistSq = (effectiveRadius * 2) * (effectiveRadius * 2)
            let radSq = effectiveRadius * effectiveRadius
            let addScale = intensity * 100 * dt * 0.01
            let speedMultiplier = min(speed * 10, 1.0)
            let Gf = Float(G)
            for i in 0..<G {
                for j in 0..<G {
                    let cellX = (Float(j) + 0.5) / Gf
                    let cellY = (Float(i) + 0.5) / Gf
                    let dx = aspect >= 1 ? (cellX - pointer.x) * aspect : cellX - pointer.x
                    let dy = aspect >= 1 ? cellY - pointer.y : (cellY - pointer.y) / aspect
                    let distSq = dx * dx + dy * dy
                    if distSq < maxDistSq {
                        let idx = (i * G + j) * 4
                        let influence = exp(-distSq / radSq)
                        tempFieldData[idx] += mouseVelX * influence * addScale
                        tempFieldData[idx + 1] += mouseVelY * influence * addScale
                        tempFieldData[idx + 2] += influence * addScale * speedMultiplier
                        tempFieldData[idx] = max(-1, min(1, tempFieldData[idx]))
                        tempFieldData[idx + 1] = max(-1, min(1, tempFieldData[idx + 1]))
                        tempFieldData[idx + 2] = max(0, min(1, tempFieldData[idx + 2]))
                    }
                }
            }
        }

        // publish(halfFloat)
        fieldMax = injecting ? 1 : newMax
        swap(&fieldData, &tempFieldData) // temp is fully rewritten next step (channel 3 stays 0)
        for k in 0..<texData.count { texData[k] = GridKit.halfBits(fieldData[k]) }
        texData.withUnsafeBytes { GridKit.upload($0, bytesPerRow: G * 8, to: field, device: ctx.device.device, cb: ctx.commandBuffer) }
        return out
    }
}
#endif
