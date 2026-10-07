import Foundation
import simd

/// Per-frame inputs shared by every layer: clock, viewport and pointer.
public struct FrameInput: Equatable, Sendable {
    /// Seconds since the view started rendering (the upstream global `time` uniform).
    public var time: Float
    /// Seconds since the previous frame (clamped to 0.1 like upstream).
    public var deltaTime: Float
    /// Backing-store size in pixels.
    public var pixelSize: SIMD2<Float>
    /// Layout size in points (upstream `logicalViewportSize`).
    public var logicalSize: SIMD2<Float>
    /// Pointer position in UV space (0...1, top-left origin).
    public var pointer: SIMD2<Float>
    /// Whether a pointer/touch is currently over the view.
    public var pointerActive: Bool

    public init(time: Float = 0, deltaTime: Float = 1.0 / 60.0, pixelSize: SIMD2<Float>, logicalSize: SIMD2<Float>? = nil, pointer: SIMD2<Float> = SIMD2(0.5, 0.5), pointerActive: Bool = false) {
        self.time = time
        self.deltaTime = deltaTime
        self.pixelSize = pixelSize
        self.logicalSize = logicalSize ?? pixelSize
        self.pointer = pointer
        self.pointerActive = pointerActive
    }

    public var aspect: Float { pixelSize.y > 0 ? pixelSize.x / pixelSize.y : 1 }
}

/// Renderer-wide options.
public struct RenderOptions: Equatable, Sendable {
    /// Working color space for colors and the output. Display P3 matches upstream.
    public var colorSpace: ColorSpaceMode = .displayP3Linear
    public var toneMapping: ToneMapping = .linear
    /// Premultiply alpha in the present pass (CAMetalLayer expects premultiplied content).
    public var premultiplyAlpha: Bool = true
    /// Clear color behind the layer stack (linear, straight alpha). Default transparent.
    public var backgroundColor: SIMD4<Float> = SIMD4(0, 0, 0, 0)

    public init(colorSpace: ColorSpaceMode = .displayP3Linear, toneMapping: ToneMapping = .linear, premultiplyAlpha: Bool = true, backgroundColor: SIMD4<Float> = SIMD4(0, 0, 0, 0)) {
        self.colorSpace = colorSpace
        self.toneMapping = toneMapping
        self.premultiplyAlpha = premultiplyAlpha
        self.backgroundColor = backgroundColor
    }
}

/// Mutable per-node state the renderer keeps between frames (animated clocks, media, sims).
public final class NodeState {
    public init() {}
    /// Component type this state was created for; a type change at the same tree position resets it.
    public var shaderName: String = ""
    /// `_animTime` and `_animTime_<key>` accumulators keyed by field name.
    public var animTime: [String: Float] = [:]
    /// Extra CPU-derived fields (`extraFields`), keyed by field name.
    public var extraFields: [String: [Float]] = [:]
    /// Last frame this state was touched (for garbage collection).
    public var lastFrame: Int = 0
    /// Opaque per-shader storage (compute/simulation programs, media textures).
    public var storage: [String: Any] = [:]
}

/// Diagnostics for the current frame (shown by the demo app's HUD).
public struct FrameStats: Equatable, Sendable {
    public var passes: Int = 0
    public var blendPasses: Int = 0
    public var nodes: Int = 0
    public var unsupportedNodes: [String] = []
    public var compileErrors: [String] = []
    /// Nodes skipped this frame because their shader library is still compiling in the background.
    public var pendingCompiles: Int = 0
    public var gpuTimeMilliseconds: Double = 0

    public init() {}
}
