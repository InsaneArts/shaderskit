#if canImport(Metal)
import Foundation

// Ports of the CPU-side pieces the fluid shaders share: the pointer tracker, idle gate and stamp
// ribbon (gpu/kit/host/pointer.ts), and the emitter / init parts of std/sim/fluids.ts.

extension FluidsFamilyProgram {

    // MARK: - Pointer tracking (kit/host/pointer.ts)

    /// The renderer's pointer for one frame (upstream `PointerLike`). `seen` is false until a real
    /// pointer has landed on the view.
    struct PointerSample {
        var x: Double
        var y: Double
        var seen: Bool
    }

    /// One frame of resolved pointer motion, in viewport UV (upstream `PointerFrame`).
    struct PointerFrame {
        var x: Double
        var y: Double
        var prevX: Double
        var prevY: Double
        /// Per-frame delta, zeroed on a teleport frame.
        var dx: Double
        var dy: Double
        /// Raw distance, reported even on a teleport frame.
        var dragDist: Double
        var velX: Double
        var velY: Double
        var smoothVelX: Double
        var smoothVelY: Double
        var smoothSpeed: Double
        var teleport: Bool
        var moving: Bool
    }

    /// Upstream `createPointerVelocityTracker`.
    final class PointerTracker {
        struct Options {
            var smoothing = 0.2
            var teleportGuard = 0.25
            var minDrag = 0.0006
            var initialX = 0.5
            var initialY = 0.5
        }

        private let opts: Options
        private var prevX: Double
        private var prevY: Double
        private var smoothVelX = 0.0
        private var smoothVelY = 0.0
        private var sawUnseen = false
        private var snappedToFirstReal = false

        init(_ opts: Options) {
            self.opts = opts
            prevX = opts.initialX
            prevY = opts.initialY
        }

        func update(_ pointer: PointerSample, dt: Double) -> PointerFrame {
            // A parked (never-seen) sample is held in place; the first real sample snaps with zero delta.
            let parked = !pointer.seen
            if parked {
                sawUnseen = true
            } else if sawUnseen && !snappedToFirstReal {
                snappedToFirstReal = true
                prevX = pointer.x
                prevY = pointer.y
            }
            let oldX = prevX
            let oldY = prevY
            let x = parked ? prevX : pointer.x
            let y = parked ? prevY : pointer.y
            let rawDx = x - oldX
            let rawDy = y - oldY
            let dragDist = (rawDx * rawDx + rawDy * rawDy).squareRoot()
            let teleport = dragDist >= opts.teleportGuard
            prevX = x
            prevY = y

            let dx = teleport ? 0 : rawDx
            let dy = teleport ? 0 : rawDy
            let invDt = 1 / max(dt, 0.001)
            let velX = dx * invDt
            let velY = dy * invDt
            smoothVelX = smoothVelX * (1 - opts.smoothing) + velX * opts.smoothing
            smoothVelY = smoothVelY * (1 - opts.smoothing) + velY * opts.smoothing
            return PointerFrame(
                x: x, y: y, prevX: oldX, prevY: oldY, dx: dx, dy: dy, dragDist: dragDist,
                velX: velX, velY: velY, smoothVelX: smoothVelX, smoothVelY: smoothVelY,
                smoothSpeed: (smoothVelX * smoothVelX + smoothVelY * smoothVelY).squareRoot(),
                teleport: teleport, moving: !teleport && dragDist > opts.minDrag
            )
        }
    }

    /// Upstream `createIdleGate` with no warm-up (the only configuration the fluids use). It counts
    /// simulated seconds since the last input and skips once the field has decayed.
    final class IdleGate {
        private var everActive = false
        private var simSinceActive = 0.0

        func markActive() {
            everActive = true
            simSinceActive = 0
        }

        func tickFrame(_ dt: Double) {
            simSinceActive += dt
        }

        func shouldSkip(_ fadeSeconds: Double) -> Bool {
            if !everActive { return true }
            return simSinceActive > fadeSeconds
        }
    }

    /// Upstream `decayFadeSeconds`: seconds for a field decaying at `rate` per second to fall by `ratio`.
    static func decayFadeSeconds(_ ratio: Double, _ rate: Double, minRate: Double = 0.05) -> Double {
        log(ratio) / max(rate, minRate)
    }

    // MARK: - Emitters (std/sim/fluids.ts)

    /// Something that injects into the field each frame (upstream `FluidEmitter`).
    class Emitter {
        /// Bookkeeping before the idle gate.
        func tick(_ f: Frame) {}
        /// True skips the whole frame.
        func skip(_ f: Frame) -> Bool { false }
        /// Encodes this frame's injection passes (they run before the solve).
        func emit(_ f: Frame, _ values: Values, _ pass: Pass) throws {}
    }

    /// Upstream `splat`: one dispatch per frame at a fixed source.
    final class Splat: Emitter {
        let kernel: Int

        init(kernel: Int) {
            self.kernel = kernel
        }

        override func emit(_ f: Frame, _ values: Values, _ pass: Pass) throws {
            try pass.dispatch(kernel)
        }
    }

    /// One frame's stamps along the stroke (upstream `CursorRibbonSpec`).
    struct RibbonSpec {
        /// Distance between stamps, in UV.
        var stepSize: Double
        var maxSteps: Int
        /// Writes one stamp's uniform at grid position (`posX`, `posY`) right before its dispatch.
        /// Upstream `prepare` and `write` both run once per stamp in stamp order, so they fold into one.
        var write: (_ pass: Pass, _ posX: Double, _ posY: Double, _ t: Double) -> Void
    }

    /// Upstream `cursorRibbon`: paints a ribbon of stamps along the pointer's path, tracks the
    /// pointer itself and sleeps the simulation `fadeSeconds` after the last activity.
    final class CursorRibbon: Emitter {
        private let tracker: PointerTracker
        private let idle = IdleGate()
        private let kernel: Int
        private let activeWhen: (PointerFrame, Frame) -> Bool
        private let fadeSeconds: (Frame) -> Double
        private let onFrame: ((Frame, PointerFrame) -> Void)?
        private let ribbon: (Frame, PointerFrame, Values) -> RibbonSpec
        private(set) var ptr: PointerFrame?
        private(set) var active = false

        init(tracker: PointerTracker.Options = .init(), kernel: Int,
             activeWhen: @escaping (PointerFrame, Frame) -> Bool,
             fadeSeconds: @escaping (Frame) -> Double,
             onFrame: ((Frame, PointerFrame) -> Void)? = nil,
             ribbon: @escaping (Frame, PointerFrame, Values) -> RibbonSpec) {
            self.tracker = PointerTracker(tracker)
            self.kernel = kernel
            self.activeWhen = activeWhen
            self.fadeSeconds = fadeSeconds
            self.onFrame = onFrame
            self.ribbon = ribbon
        }

        override func tick(_ f: Frame) {
            let p = tracker.update(f.pointer, dt: f.dt)
            ptr = p
            onFrame?(f, p)
            active = activeWhen(p, f)
            if active { idle.markActive() }
        }

        override func skip(_ f: Frame) -> Bool {
            let skip = idle.shouldSkip(fadeSeconds(f))
            // Only frames that step the field count toward its decay budget.
            if !skip { idle.tickFrame(f.dt) }
            return skip
        }

        override func emit(_ f: Frame, _ values: Values, _ pass: Pass) throws {
            guard active, let p = ptr else { return }
            let spec = ribbon(f, p, values)
            // Upstream `pathStampRibbon`: stamps at segment centres along this frame's drag path.
            let scale = Double(FluidsFamilyProgram.n)
            let numSteps = min(spec.maxSteps, max(1, Int((p.dragDist / spec.stepSize).rounded(.up))))
            for s in 0..<numSteps {
                let t = (Double(s) + 0.5) / Double(numSteps)
                spec.write(pass, (p.prevX + p.dx * t) * scale, (p.prevY + p.dy * t) * scale, t)
                try pass.dispatch(kernel)
            }
        }
    }

    // MARK: - Init parts

    /// Upstream `seededFieldInit`: seeds the field when `seed` changes (or on the first frame), then
    /// runs `warmSteps` silent solves so the first visible frame already flows.
    final class SeededFieldInit {
        let kernel: Int
        let seed: (Frame) -> Double
        let warmSteps: Int
        let warmJacobiIters: Int
        let warmDt: Double
        let startTime: () -> Double
        let values: (Double, Frame) -> Values
        private var initialized = false
        private var lastSeed = -1.0

        init(kernel: Int, seed: @escaping (Frame) -> Double, warmSteps: Int, warmJacobiIters: Int, warmDt: Double,
             startTime: @escaping () -> Double, values: @escaping (Double, Frame) -> Values) {
            self.kernel = kernel
            self.seed = seed
            self.warmSteps = warmSteps
            self.warmJacobiIters = warmJacobiIters
            self.warmDt = warmDt
            self.startTime = startTime
            self.values = values
        }

        func stale(_ f: Frame) -> Bool {
            !initialized || seed(f) != lastSeed
        }

        func run(_ f: inout Frame, _ pass: Pass, paramsUniform: String) throws {
            initialized = true
            lastSeed = seed(f)
            pass.write(paramsUniform, values(0, f))
            try pass.dispatch(kernel)
            var warmTime = startTime()
            for _ in 0..<warmSteps {
                let wt = warmTime
                warmTime += warmDt
                pass.write(paramsUniform, values(wt, f))
                try pass.solve(jacobiIters: warmJacobiIters)
            }
            f.elapsed = warmTime
        }
    }
}
#endif
