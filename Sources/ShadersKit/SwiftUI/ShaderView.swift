import Foundation
import SwiftUI
import simd

#if canImport(MetalKit) && !os(watchOS)
import Metal
import MetalKit
import QuartzCore

/// A view that renders a stack of shader layers with Metal, continuously.
///
/// ```swift
/// ShaderView {
///     LinearGradient(colorA: "#0f172a", colorB: "#7c3aed")
///     Blur(intensity: 40) { Circle(radius: 0.5, color: "#ff2b6e") }
///         .blendMode(.screen)
/// }
/// ```
public struct ShaderView: View {
    public var nodes: [ShaderNode]
    public var options: RenderOptions
    public var isPaused: Bool
    public var preferredFramesPerSecond: Int
    public var onFrame: ((FrameStats) -> Void)?

    public init(options: RenderOptions = RenderOptions(), isPaused: Bool = false, preferredFramesPerSecond: Int = 60, onFrame: ((FrameStats) -> Void)? = nil, @ShaderLayerBuilder content: () -> [ShaderNode]) {
        self.nodes = content()
        self.options = options
        self.isPaused = isPaused
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.onFrame = onFrame
    }

    public init(nodes: [ShaderNode], options: RenderOptions = RenderOptions(), isPaused: Bool = false, preferredFramesPerSecond: Int = 60, onFrame: ((FrameStats) -> Void)? = nil) {
        self.nodes = nodes
        self.options = options
        self.isPaused = isPaused
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.onFrame = onFrame
    }

    public var body: some View {
        MetalShaderViewRepresentable(nodes: nodes, options: options, isPaused: isPaused, fps: preferredFramesPerSecond, onFrame: onFrame)
    }
}

// MARK: - Platform view

/// `MTKView` subclass that owns a `ShaderRenderer`, tracks the pointer and renders every frame.
public final class ShaderMetalView: MTKView, MTKViewDelegate {
    public var nodes: [ShaderNode] = []
    public var options = RenderOptions() {
        didSet { applyColorSpace() }
    }
    public var onFrame: ((FrameStats) -> Void)?
    public private(set) var renderer: ShaderRenderer?
    public private(set) var lastStats = FrameStats()

    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var lastTime: CFTimeInterval = 0
    private var pointer = SIMD2<Float>(0.5, 0.5)
    private var pointerActive = false
    private var pausedTime: CFTimeInterval = 0

    public init(shaderDevice: ShaderDevice? = ShaderDevice.shared) {
        super.init(frame: .zero, device: shaderDevice?.device)
        if let shaderDevice { renderer = ShaderRenderer(device: shaderDevice) }
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        isPaused = false
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        delegate = self
        applyColorSpace()
        #if os(macOS)
        layer?.isOpaque = false
        #else
        isOpaque = false
        backgroundColor = .clear
        #endif
        setupPointerTracking()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func applyColorSpace() {
        guard let metalLayer = layer as? CAMetalLayer else { return }
        switch options.colorSpace {
        case .displayP3Linear: metalLayer.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
        case .sRGBLinear: metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        }
        metalLayer.isOpaque = false
    }

    /// Sets the pointer position in view coordinates (points, top-left origin).
    public func setPointer(location: CGPoint?, active: Bool) {
        if let location, bounds.width > 0, bounds.height > 0 {
            pointer = SIMD2(Float(location.x / bounds.width), Float(location.y / bounds.height))
        }
        pointerActive = active
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    public func draw(in view: MTKView) {
        guard let renderer, let drawable = currentDrawable, let cb = renderer.device.queue.makeCommandBuffer() else { return }
        let now = CACurrentMediaTime()
        let dt = lastTime == 0 ? 1.0 / 60.0 : min(now - lastTime, 0.1)
        lastTime = now
        let size = drawableSize
        let frame = FrameInput(
            time: Float(now - startTime),
            deltaTime: Float(dt),
            pixelSize: SIMD2(Float(size.width), Float(size.height)),
            logicalSize: SIMD2(Float(bounds.width), Float(bounds.height)),
            pointer: pointer,
            pointerActive: pointerActive
        )
        renderer.options = options
        renderer.render(nodes, frame: frame, into: drawable.texture, commandBuffer: cb)
        lastStats = renderer.stats
        cb.present(drawable)
        cb.commit()
        onFrame?(lastStats)
    }

    // MARK: pointer tracking

    private func setupPointerTracking() {
        #if os(macOS)
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        #elseif os(iOS) || os(visionOS)
        let hover = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hover)
        isMultipleTouchEnabled = false
        #endif
    }

    #if os(macOS)
    public override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        setPointer(location: CGPoint(x: p.x, y: bounds.height - p.y), active: true)
    }
    public override func mouseDragged(with event: NSEvent) { mouseMoved(with: event) }
    public override func mouseDown(with event: NSEvent) { mouseMoved(with: event) }
    public override func mouseExited(with event: NSEvent) { setPointer(location: nil, active: false) }
    public override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    public override var acceptsFirstResponder: Bool { true }
    #elseif os(iOS) || os(tvOS) || os(visionOS)
    #if !os(tvOS)
    @objc private func handleHover(_ g: UIHoverGestureRecognizer) {
        switch g.state {
        case .began, .changed: setPointer(location: g.location(in: self), active: true)
        default: setPointer(location: nil, active: false)
        }
    }
    #endif
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { setPointer(location: t.location(in: self), active: true) }
    }
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { setPointer(location: t.location(in: self), active: true) }
    }
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        setPointer(location: nil, active: false)
    }
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        setPointer(location: nil, active: false)
    }
    #endif
}

#if os(macOS)
struct MetalShaderViewRepresentable: NSViewRepresentable {
    var nodes: [ShaderNode]
    var options: RenderOptions
    var isPaused: Bool
    var fps: Int
    var onFrame: ((FrameStats) -> Void)?

    func makeNSView(context: Context) -> ShaderMetalView {
        let v = ShaderMetalView()
        update(v)
        return v
    }

    func updateNSView(_ nsView: ShaderMetalView, context: Context) { update(nsView) }

    private func update(_ v: ShaderMetalView) {
        v.nodes = nodes
        if v.options != options { v.options = options }
        v.isPaused = isPaused
        v.preferredFramesPerSecond = fps
        v.onFrame = onFrame
    }
}
#else
struct MetalShaderViewRepresentable: UIViewRepresentable {
    var nodes: [ShaderNode]
    var options: RenderOptions
    var isPaused: Bool
    var fps: Int
    var onFrame: ((FrameStats) -> Void)?

    func makeUIView(context: Context) -> ShaderMetalView {
        let v = ShaderMetalView()
        update(v)
        return v
    }

    func updateUIView(_ uiView: ShaderMetalView, context: Context) { update(uiView) }

    private func update(_ v: ShaderMetalView) {
        v.nodes = nodes
        if v.options != options { v.options = options }
        v.isPaused = isPaused
        v.preferredFramesPerSecond = fps
        v.onFrame = onFrame
    }
}
#endif

#else

/// watchOS: no Metal. Renders with the CPU rasterizer where a CPU port exists.
public struct ShaderView: View {
    public var nodes: [ShaderNode]
    public var options: RenderOptions
    public var isPaused: Bool
    public var preferredFramesPerSecond: Int
    public var onFrame: ((FrameStats) -> Void)?

    public init(options: RenderOptions = RenderOptions(), isPaused: Bool = false, preferredFramesPerSecond: Int = 30, onFrame: ((FrameStats) -> Void)? = nil, @ShaderLayerBuilder content: () -> [ShaderNode]) {
        self.nodes = content()
        self.options = options
        self.isPaused = isPaused
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.onFrame = onFrame
    }

    public init(nodes: [ShaderNode], options: RenderOptions = RenderOptions(), isPaused: Bool = false, preferredFramesPerSecond: Int = 30, onFrame: ((FrameStats) -> Void)? = nil) {
        self.nodes = nodes
        self.options = options
        self.isPaused = isPaused
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.onFrame = onFrame
    }

    public var body: some View {
        CPUShaderView(nodes: nodes, options: options, isPaused: isPaused, fps: preferredFramesPerSecond, onFrame: onFrame)
    }
}
#endif
