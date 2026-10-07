// CPU rasterizer runtime: the WGSL builtins and resources the generated Swift shader code calls.
// Shared by the watchOS renderer and by cross-checking tests on the other platforms.
import Foundation
import simd

/// A CPU-side RGBA float texture (linear light, straight alpha).
public final class CPUTexture: @unchecked Sendable {
    public let width: Int
    public let height: Int
    /// Row-major RGBA pixels.
    public var pixels: [SIMD4<Float>]

    public init(width: Int, height: Int, fill: SIMD4<Float> = SIMD4()) {
        self.width = max(1, width)
        self.height = max(1, height)
        pixels = [SIMD4<Float>](repeating: fill, count: self.width * self.height)
    }

    public var dimensions: SIMD2<UInt32> { SIMD2(UInt32(width), UInt32(height)) }

    @inline(__always) public func load(_ coord: SIMD2<UInt32>) -> SIMD4<Float> {
        let x = min(Int(coord.x), width - 1)
        let y = min(Int(coord.y), height - 1)
        return pixels[y * width + x]
    }

    @inline(__always) public func load(_ coord: SIMD2<Int32>) -> SIMD4<Float> {
        let x = min(max(Int(coord.x), 0), width - 1)
        let y = min(max(Int(coord.y), 0), height - 1)
        return pixels[y * width + x]
    }

    @inline(__always) public func texel(_ x: Int, _ y: Int) -> SIMD4<Float> {
        pixels[y * width + x]
    }

    /// Bilinear or nearest sampling with the sampler's address mode (normalized coordinates).
    @inline(__always) public func sample(_ sampler: CPUSampler, _ uv: SIMD2<Float>) -> SIMD4<Float> {
        var u = uv.x
        var v = uv.y
        if u.isNaN { u = 0 }
        if v.isNaN { v = 0 }
        let fw = Float(width)
        let fh = Float(height)
        if sampler.repeats {
            u -= u.rounded(.down)
            v -= v.rounded(.down)
        }
        var px = u * fw - 0.5
        var py = v * fh - 0.5
        if sampler.linear {
            let x0f = px.rounded(.down)
            let y0f = py.rounded(.down)
            let tx = px - x0f
            let ty = py - y0f
            let x0 = wrap(Int(x0f), width, sampler.repeats)
            let x1 = wrap(Int(x0f) + 1, width, sampler.repeats)
            let y0 = wrap(Int(y0f), height, sampler.repeats)
            let y1 = wrap(Int(y0f) + 1, height, sampler.repeats)
            let a = pixels[y0 * width + x0]
            let b = pixels[y0 * width + x1]
            let c = pixels[y1 * width + x0]
            let d = pixels[y1 * width + x1]
            let top = a + (b - a) * tx
            let bottom = c + (d - c) * tx
            return top + (bottom - top) * ty
        }
        px = (px + 0.5).rounded(.down)
        py = (py + 0.5).rounded(.down)
        let x = wrap(Int(px), width, sampler.repeats)
        let y = wrap(Int(py), height, sampler.repeats)
        return pixels[y * width + x]
    }

    @inline(__always) private func wrap(_ i: Int, _ n: Int, _ repeats: Bool) -> Int {
        if repeats {
            let m = i % n
            return m < 0 ? m + n : m
        }
        return min(max(i, 0), n - 1)
    }
}

/// Sampler state (filter + address mode), matching the upstream shared samplers.
public struct CPUSampler: Sendable, Equatable {
    public var linear: Bool
    public var repeats: Bool

    public static let linearClamp = CPUSampler(linear: true, repeats: false)
    public static let nearestClamp = CPUSampler(linear: false, repeats: false)
    public static let linearRepeat = CPUSampler(linear: true, repeats: true)
    public static let nearestRepeat = CPUSampler(linear: false, repeats: true)

    public static func named(_ name: String) -> CPUSampler {
        switch name {
        case "nearestClamp": return .nearestClamp
        case "linearRepeat": return .linearRepeat
        case "nearestRepeat": return .nearestRepeat
        default: return .linearClamp
        }
    }
}

/// Fragment stage input (the fullscreen triangle's interpolated UV, top-left origin).
public struct CPUFragmentInput {
    public var uv: SIMD2<Float>
}

/// Per-pass environment: decoded once, captured by the per-pixel closure.
public struct CPUPassEnvironment {
    public var uniformBytes: UnsafeRawPointer
    public var textures: [String: CPUTexture]
    public var placeholder: CPUTexture

    public func texture(_ key: String) -> CPUTexture {
        textures[key] ?? placeholder
    }
}

/// Per-pixel context.
public struct CPUPassContext {
    public var input: CPUFragmentInput
    /// Size of one pixel in UV units (used to approximate screen-space derivatives).
    public var pixelSizeUV: SIMD2<Float>
}

public typealias CPUPixelFunction = (CPUPassContext) -> SIMD4<Float>
public typealias CPUPassFactory = (CPUPassEnvironment) -> CPUPixelFunction

/// A generated CPU shader program: one factory per pass entry point.
public protocol CPUShaderProgram {
    static var passes: [String: CPUPassFactory] { get }
}

// MARK: - WGSL builtins (scalar + vector overloads)

@inline(__always) func sk_mix(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }
@inline(__always) func sk_mix<V: SIMD>(_ a: V, _ b: V, _ t: V) -> V where V.Scalar == Float { a + (b - a) * t }
@inline(__always) func sk_mix<V: SIMD>(_ a: V, _ b: V, _ t: Float) -> V where V.Scalar == Float { a + (b - a) * t }

@inline(__always) func sk_clamp(_ x: Float, _ lo: Float, _ hi: Float) -> Float { min(max(x, lo), hi) }
@inline(__always) func sk_clamp(_ x: Int32, _ lo: Int32, _ hi: Int32) -> Int32 { min(max(x, lo), hi) }
@inline(__always) func sk_clamp(_ x: UInt32, _ lo: UInt32, _ hi: UInt32) -> UInt32 { min(max(x, lo), hi) }
@inline(__always) func sk_clamp<V: SIMD>(_ x: V, _ lo: V, _ hi: V) -> V where V.Scalar: Comparable { pointwiseMin(pointwiseMax(x, lo), hi) }

@inline(__always) func sk_min(_ a: Float, _ b: Float) -> Float { min(a, b) }
@inline(__always) func sk_max(_ a: Float, _ b: Float) -> Float { max(a, b) }
@inline(__always) func sk_min(_ a: Int32, _ b: Int32) -> Int32 { min(a, b) }
@inline(__always) func sk_max(_ a: Int32, _ b: Int32) -> Int32 { max(a, b) }
@inline(__always) func sk_min(_ a: UInt32, _ b: UInt32) -> UInt32 { min(a, b) }
@inline(__always) func sk_max(_ a: UInt32, _ b: UInt32) -> UInt32 { max(a, b) }
@inline(__always) func sk_min<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable { pointwiseMin(a, b) }
@inline(__always) func sk_max<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: Comparable { pointwiseMax(a, b) }

@inline(__always) func sk_step(_ edge: Float, _ x: Float) -> Float { x < edge ? 0 : 1 }
@inline(__always) func sk_step<V: SIMD>(_ edge: V, _ x: V) -> V where V.Scalar == Float {
    var r = V(repeating: 1)
    r.replace(with: 0, where: x .< edge)
    return r
}

@inline(__always) func sk_smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = sk_clamp((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)
}
@inline(__always) func sk_smoothstep<V: SIMD>(_ e0: V, _ e1: V, _ x: V) -> V where V.Scalar == Float {
    let t = sk_clamp((x - e0) / (e1 - e0), V(repeating: 0), V(repeating: 1))
    return t * t * (V(repeating: 3) - 2 * t)
}

@inline(__always) func sk_fract(_ x: Float) -> Float { x - x.rounded(.down) }
@inline(__always) func sk_fract<V: SIMD>(_ x: V) -> V where V.Scalar == Float { x - x.rounded(.down) }
@inline(__always) func sk_floor(_ x: Float) -> Float { x.rounded(.down) }
@inline(__always) func sk_floor<V: SIMD>(_ x: V) -> V where V.Scalar == Float { x.rounded(.down) }
@inline(__always) func sk_ceil(_ x: Float) -> Float { x.rounded(.up) }
@inline(__always) func sk_ceil<V: SIMD>(_ x: V) -> V where V.Scalar == Float { x.rounded(.up) }
@inline(__always) func sk_trunc(_ x: Float) -> Float { x.rounded(.towardZero) }
@inline(__always) func sk_trunc<V: SIMD>(_ x: V) -> V where V.Scalar == Float { x.rounded(.towardZero) }
/// WGSL `round` rounds half to even.
@inline(__always) func sk_round(_ x: Float) -> Float { x.rounded(.toNearestOrEven) }
@inline(__always) func sk_round<V: SIMD>(_ x: V) -> V where V.Scalar == Float { x.rounded(.toNearestOrEven) }
@inline(__always) func sk_abs(_ x: Float) -> Float { abs(x) }
@inline(__always) func sk_abs(_ x: Int32) -> Int32 { x == Int32.min ? x : abs(x) }
@inline(__always) func sk_abs<V: SIMD>(_ x: V) -> V where V.Scalar == Float { pointwiseMax(x, -x) }
@inline(__always) func sk_sign(_ x: Float) -> Float { x > 0 ? 1 : (x < 0 ? -1 : 0) }
@inline(__always) func sk_sign(_ x: Int32) -> Int32 { x > 0 ? 1 : (x < 0 ? -1 : 0) }
@inline(__always) func sk_sign<V: SIMD>(_ x: V) -> V where V.Scalar == Float {
    var r = V(repeating: 0)
    r.replace(with: 1, where: x .> 0)
    r.replace(with: -1, where: x .< 0)
    return r
}
@inline(__always) func sk_saturate(_ x: Float) -> Float { sk_clamp(x, 0, 1) }
@inline(__always) func sk_saturate<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_clamp(x, V(repeating: 0), V(repeating: 1)) }

@inline(__always) func sk_sqrt(_ x: Float) -> Float { x.squareRoot() }
@inline(__always) func sk_sqrt<V: SIMD>(_ x: V) -> V where V.Scalar == Float { x.squareRoot() }
@inline(__always) func sk_rsqrt(_ x: Float) -> Float { 1 / x.squareRoot() }
@inline(__always) func sk_rsqrt<V: SIMD>(_ x: V) -> V where V.Scalar == Float { V(repeating: 1) / x.squareRoot() }

@inline(__always) func sk_map<V: SIMD>(_ x: V, _ f: (Float) -> Float) -> V where V.Scalar == Float {
    var r = x
    for i in 0..<V.scalarCount { r[i] = f(x[i]) }
    return r
}
@inline(__always) func sk_sin(_ x: Float) -> Float { Foundation.sin(x) }
@inline(__always) func sk_sin<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.sin) }
@inline(__always) func sk_cos(_ x: Float) -> Float { Foundation.cos(x) }
@inline(__always) func sk_cos<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.cos) }
@inline(__always) func sk_tan(_ x: Float) -> Float { Foundation.tan(x) }
@inline(__always) func sk_tan<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.tan) }
@inline(__always) func sk_asin(_ x: Float) -> Float { Foundation.asin(x) }
@inline(__always) func sk_asin<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.asin) }
@inline(__always) func sk_acos(_ x: Float) -> Float { Foundation.acos(x) }
@inline(__always) func sk_acos<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.acos) }
@inline(__always) func sk_atan(_ x: Float) -> Float { Foundation.atan(x) }
@inline(__always) func sk_atan<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.atan) }
@inline(__always) func sk_sinh(_ x: Float) -> Float { Foundation.sinh(x) }
@inline(__always) func sk_sinh<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.sinh) }
@inline(__always) func sk_cosh(_ x: Float) -> Float { Foundation.cosh(x) }
@inline(__always) func sk_cosh<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.cosh) }
@inline(__always) func sk_tanh(_ x: Float) -> Float { Foundation.tanh(x) }
@inline(__always) func sk_tanh<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.tanh) }
@inline(__always) func sk_exp(_ x: Float) -> Float { Foundation.exp(x) }
@inline(__always) func sk_exp<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.exp) }
@inline(__always) func sk_exp2(_ x: Float) -> Float { Foundation.exp2(x) }
@inline(__always) func sk_exp2<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.exp2) }
@inline(__always) func sk_log(_ x: Float) -> Float { Foundation.log(x) }
@inline(__always) func sk_log<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.log) }
@inline(__always) func sk_log2(_ x: Float) -> Float { Foundation.log2(x) }
@inline(__always) func sk_log2<V: SIMD>(_ x: V) -> V where V.Scalar == Float { sk_map(x, Foundation.log2) }
@inline(__always) func sk_pow(_ x: Float, _ y: Float) -> Float { Foundation.pow(x, y) }
@inline(__always) func sk_pow<V: SIMD>(_ x: V, _ y: V) -> V where V.Scalar == Float {
    var r = x
    for i in 0..<V.scalarCount { r[i] = Foundation.pow(x[i], y[i]) }
    return r
}
@inline(__always) func sk_atan2(_ y: Float, _ x: Float) -> Float { Foundation.atan2(y, x) }
@inline(__always) func sk_atan2<V: SIMD>(_ y: V, _ x: V) -> V where V.Scalar == Float {
    var r = y
    for i in 0..<V.scalarCount { r[i] = Foundation.atan2(y[i], x[i]) }
    return r
}
@inline(__always) func sk_fma(_ a: Float, _ b: Float, _ c: Float) -> Float { a * b + c }
@inline(__always) func sk_fma<V: SIMD>(_ a: V, _ b: V, _ c: V) -> V where V.Scalar == Float { a * b + c }

/// WGSL float `%`: truncated remainder (like C fmod).
@inline(__always) func sk_fmod(_ a: Float, _ b: Float) -> Float { a - b * (a / b).rounded(.towardZero) }
@inline(__always) func sk_fmod<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar == Float { a - b * (a / b).rounded(.towardZero) }
@inline(__always) func sk_idiv(_ a: Int32, _ b: Int32) -> Int32 { b == 0 ? a : (a == Int32.min && b == -1 ? a : a / b) }
@inline(__always) func sk_idiv(_ a: UInt32, _ b: UInt32) -> UInt32 { b == 0 ? a : a / b }
@inline(__always) func sk_imod(_ a: Int32, _ b: Int32) -> Int32 { b == 0 ? 0 : (b == -1 ? 0 : a % b) }
@inline(__always) func sk_imod(_ a: UInt32, _ b: UInt32) -> UInt32 { b == 0 ? 0 : a % b }
@inline(__always) func sk_idiv<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar == Int32 {
    var r = a
    for i in 0..<V.scalarCount { r[i] = sk_idiv(a[i], b[i]) }
    return r
}
@inline(__always) func sk_idiv<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar == UInt32 {
    var r = a
    for i in 0..<V.scalarCount { r[i] = sk_idiv(a[i], b[i]) }
    return r
}
@inline(__always) func sk_imod<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar == Int32 {
    var r = a
    for i in 0..<V.scalarCount { r[i] = sk_imod(a[i], b[i]) }
    return r
}
@inline(__always) func sk_imod<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar == UInt32 {
    var r = a
    for i in 0..<V.scalarCount { r[i] = sk_imod(a[i], b[i]) }
    return r
}

@inline(__always) func sk_length(_ v: Float) -> Float { abs(v) }
@inline(__always) func sk_length<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar == Float { (v * v).sum().squareRoot() }
@inline(__always) func sk_distance<V: SIMD>(_ a: V, _ b: V) -> Float where V.Scalar == Float { sk_length(a - b) }
@inline(__always) func sk_distance(_ a: Float, _ b: Float) -> Float { abs(a - b) }
@inline(__always) func sk_dot<V: SIMD>(_ a: V, _ b: V) -> Float where V.Scalar == Float { (a * b).sum() }
@inline(__always) func sk_normalize<V: SIMD>(_ v: V) -> V where V.Scalar == Float {
    let l = sk_length(v)
    return l > 0 ? v / l : v
}
@inline(__always) func sk_cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { simd_cross(a, b) }
@inline(__always) func sk_reflect<V: SIMD>(_ i: V, _ n: V) -> V where V.Scalar == Float { i - 2 * sk_dot(n, i) * n }
@inline(__always) func sk_refract<V: SIMD>(_ i: V, _ n: V, _ eta: Float) -> V where V.Scalar == Float {
    let d = sk_dot(n, i)
    let k = 1 - eta * eta * (1 - d * d)
    if k < 0 { return V(repeating: 0) }
    return eta * i - (eta * d + k.squareRoot()) * n
}
@inline(__always) func sk_transpose(_ m: simd_float3x3) -> simd_float3x3 { m.transpose }
@inline(__always) func sk_transpose(_ m: simd_float2x2) -> simd_float2x2 { m.transpose }
@inline(__always) func sk_transpose(_ m: simd_float4x4) -> simd_float4x4 { m.transpose }
@inline(__always) func sk_determinant(_ m: simd_float3x3) -> Float { m.determinant }
@inline(__always) func sk_determinant(_ m: simd_float2x2) -> Float { m.determinant }
@inline(__always) func sk_determinant(_ m: simd_float4x4) -> Float { m.determinant }

// conversions (WGSL saturating semantics)
@inline(__always) func sk_i32(_ x: Float) -> Int32 { x.isNaN ? 0 : Int32(max(min(x, 2147483520), -2147483648)) }
@inline(__always) func sk_i32(_ x: UInt32) -> Int32 { Int32(truncatingIfNeeded: x) }
@inline(__always) func sk_i32(_ x: Int32) -> Int32 { x }
@inline(__always) func sk_i32(_ x: Bool) -> Int32 { x ? 1 : 0 }
@inline(__always) func sk_u32(_ x: Float) -> UInt32 { x.isNaN ? 0 : UInt32(max(min(x, 4294967040), 0)) }
@inline(__always) func sk_u32(_ x: Int32) -> UInt32 { UInt32(truncatingIfNeeded: x) }
@inline(__always) func sk_u32(_ x: UInt32) -> UInt32 { x }
@inline(__always) func sk_u32(_ x: Bool) -> UInt32 { x ? 1 : 0 }
@inline(__always) func sk_i32(_ x: SIMD2<Float>) -> SIMD2<Int32> { SIMD2(sk_i32(x.x), sk_i32(x.y)) }
@inline(__always) func sk_i32(_ x: SIMD3<Float>) -> SIMD3<Int32> { SIMD3(sk_i32(x.x), sk_i32(x.y), sk_i32(x.z)) }
@inline(__always) func sk_i32(_ x: SIMD4<Float>) -> SIMD4<Int32> { SIMD4(sk_i32(x.x), sk_i32(x.y), sk_i32(x.z), sk_i32(x.w)) }
@inline(__always) func sk_i32(_ x: SIMD2<UInt32>) -> SIMD2<Int32> { SIMD2(truncatingIfNeeded: x) }
@inline(__always) func sk_i32(_ x: SIMD3<UInt32>) -> SIMD3<Int32> { SIMD3(truncatingIfNeeded: x) }
@inline(__always) func sk_i32(_ x: SIMD4<UInt32>) -> SIMD4<Int32> { SIMD4(truncatingIfNeeded: x) }
@inline(__always) func sk_u32(_ x: SIMD2<Float>) -> SIMD2<UInt32> { SIMD2(sk_u32(x.x), sk_u32(x.y)) }
@inline(__always) func sk_u32(_ x: SIMD3<Float>) -> SIMD3<UInt32> { SIMD3(sk_u32(x.x), sk_u32(x.y), sk_u32(x.z)) }
@inline(__always) func sk_u32(_ x: SIMD4<Float>) -> SIMD4<UInt32> { SIMD4(sk_u32(x.x), sk_u32(x.y), sk_u32(x.z), sk_u32(x.w)) }
@inline(__always) func sk_u32(_ x: SIMD2<Int32>) -> SIMD2<UInt32> { SIMD2(truncatingIfNeeded: x) }
@inline(__always) func sk_u32(_ x: SIMD3<Int32>) -> SIMD3<UInt32> { SIMD3(truncatingIfNeeded: x) }
@inline(__always) func sk_u32(_ x: SIMD4<Int32>) -> SIMD4<UInt32> { SIMD4(truncatingIfNeeded: x) }

// bit ops
@inline(__always) func sk_reverseBits(_ x: UInt32) -> UInt32 { UInt32(x.bitPattern.reversed) }
@inline(__always) func sk_extractBits(_ x: UInt32, _ offset: UInt32, _ count: UInt32) -> UInt32 {
    let o = min(offset, 32)
    let c = min(count, 32 - o)
    if c == 0 { return 0 }
    let mask: UInt32 = c >= 32 ? UInt32.max : ((1 << c) - 1)
    return (x &>> o) & mask
}
@inline(__always) func sk_extractBits(_ x: Int32, _ offset: UInt32, _ count: UInt32) -> Int32 {
    let o = min(offset, 32)
    let c = min(count, 32 - o)
    if c == 0 { return 0 }
    let shifted = Int32(truncatingIfNeeded: (UInt32(bitPattern: x) &>> o))
    let sh = Int32(32 - c)
    return (shifted &<< sh) &>> sh
}

private extension UInt32 {
    var bitPattern: UInt32 { self }
    var reversed: UInt32 {
        var v = self
        var r: UInt32 = 0
        for _ in 0..<32 { r = (r << 1) | (v & 1); v >>= 1 }
        return r
    }
}

// derivatives: approximated by one pixel in UV space (constant per pass; set by the renderer)
enum CPUDerivatives {
    nonisolated(unsafe) static var pixelSizeUV = SIMD2<Float>(1.0 / 256.0, 1.0 / 256.0)
}
@inline(__always) func sk_fwidth(_ x: Float) -> Float { max(CPUDerivatives.pixelSizeUV.x, CPUDerivatives.pixelSizeUV.y) }
@inline(__always) func sk_fwidth<V: SIMD>(_ x: V) -> V where V.Scalar == Float { V(repeating: max(CPUDerivatives.pixelSizeUV.x, CPUDerivatives.pixelSizeUV.y)) }
@inline(__always) func sk_dpdx(_ x: Float) -> Float { CPUDerivatives.pixelSizeUV.x }
@inline(__always) func sk_dpdx<V: SIMD>(_ x: V) -> V where V.Scalar == Float { V(repeating: CPUDerivatives.pixelSizeUV.x) }
@inline(__always) func sk_dpdy(_ x: Float) -> Float { CPUDerivatives.pixelSizeUV.y }
@inline(__always) func sk_dpdy<V: SIMD>(_ x: V) -> V where V.Scalar == Float { V(repeating: CPUDerivatives.pixelSizeUV.y) }

// swizzle helpers for complex expressions
@inline(__always) func sk_tmp<T>(_ x: T) -> T { x }
@inline(__always) func sk_swz2<V: SIMD>(_ v: V, _ a: Int, _ b: Int) -> SIMD2<V.Scalar> { SIMD2(v[a], v[b]) }
@inline(__always) func sk_swz3<V: SIMD>(_ v: V, _ a: Int, _ b: Int, _ c: Int) -> SIMD3<V.Scalar> { SIMD3(v[a], v[b], v[c]) }
@inline(__always) func sk_swz4<V: SIMD>(_ v: V, _ a: Int, _ b: Int, _ c: Int, _ d: Int) -> SIMD4<V.Scalar> { SIMD4(v[a], v[b], v[c], v[d]) }

// raw uniform loads (WGSL layout)
@inline(__always) func sk_loadF32(_ p: UnsafeRawPointer, _ o: Int) -> Float { p.loadUnaligned(fromByteOffset: o, as: Float.self) }
@inline(__always) func sk_loadI32(_ p: UnsafeRawPointer, _ o: Int) -> Int32 { p.loadUnaligned(fromByteOffset: o, as: Int32.self) }
@inline(__always) func sk_loadU32(_ p: UnsafeRawPointer, _ o: Int) -> UInt32 { p.loadUnaligned(fromByteOffset: o, as: UInt32.self) }
@inline(__always) func sk_loadV2(_ p: UnsafeRawPointer, _ o: Int) -> SIMD2<Float> { SIMD2(sk_loadF32(p, o), sk_loadF32(p, o + 4)) }
@inline(__always) func sk_loadV3(_ p: UnsafeRawPointer, _ o: Int) -> SIMD3<Float> { SIMD3(sk_loadF32(p, o), sk_loadF32(p, o + 4), sk_loadF32(p, o + 8)) }
@inline(__always) func sk_loadV4(_ p: UnsafeRawPointer, _ o: Int) -> SIMD4<Float> { SIMD4(sk_loadF32(p, o), sk_loadF32(p, o + 4), sk_loadF32(p, o + 8), sk_loadF32(p, o + 12)) }
