import Foundation

/// One stop of a multi-stop gradient. Mirrors upstream `ColorStop`.
public struct ColorStop: Equatable, Sendable {
    /// CSS color string (hex, rgb, named, …).
    public var color: String
    /// Position along the gradient axis, 0...1.
    public var position: Float

    public init(color: String, position: Float) {
        self.color = color
        self.position = position
    }
}

/// Color stops packed into the fixed-size uniform array layout. Mirrors upstream `PackedStops`.
public struct PackedStops: Equatable, Sendable {
    /// RGBA per stop, flat: `ColorStops.maxStops * 4` floats.
    public var colors: [Float]
    /// Position per stop: `ColorStops.maxStops` floats.
    public var positions: [Float]
    /// Number of active stops.
    public var stopCount: Int

    public init(colors: [Float], positions: [Float], stopCount: Int) {
        self.colors = colors
        self.positions = positions
        self.stopCount = stopCount
    }
}

/// Ports of the CPU pack functions in upstream `gpu/kit/colorStops.ts`.
public enum ColorStops {

    /// Upstream `MAX_COLOR_STOPS`.
    public static let maxStops = 8

    /// Port of `sortStops`: a stable sort by position that keeps each color with its position.
    public static func sort(_ stops: [ColorStop]) -> [ColorStop] {
        stops.enumerated()
            .sorted { a, b in
                // JS comparator: (a.position - b.position) || (a.index - b.index)
                let d = a.element.position - b.element.position
                if d != 0 && !d.isNaN { return d < 0 }
                return a.offset < b.offset
            }
            .map(\.element)
    }

    /// Port of `packStops`: sorts the stops and packs at most `maxStops` of them.
    ///
    /// Each color goes through `CSSColor.linear(_:mode:)`. `nil` or empty input gives
    /// `stopCount` 0 and all-zero arrays.
    public static func pack(_ stops: [ColorStop]?, mode: ColorSpaceMode) -> PackedStops {
        var colors = [Float](repeating: 0, count: maxStops * 4)
        var positions = [Float](repeating: 0, count: maxStops)
        let sorted = sort(stops ?? [])
        let n = min(sorted.count, maxStops)
        for i in 0..<n {
            let c = CSSColor.linear(sorted[i].color, mode: mode)
            colors[i * 4] = c.r
            colors[i * 4 + 1] = c.g
            colors[i * 4 + 2] = c.b
            colors[i * 4 + 3] = c.a
            positions[i] = sorted[i].position
        }
        return PackedStops(colors: colors, positions: positions, stopCount: n)
    }

    /// Port of `packConvertedStops`: converts the packed stop colors to the mix space of
    /// `colorSpaceMode` with `ColorMath.convertP3ToMixSpaceCPU`.
    ///
    /// - Returns: `maxStops * 3` floats. Only the first `stopCount` triplets are set.
    public static func packConverted(colors: [Float], stopCount: Int, colorSpaceMode: Int) -> [Float] {
        var out = [Float](repeating: 0, count: maxStops * 3)
        let n = max(0, min(stopCount, maxStops))
        for i in 0..<n where i * 4 + 2 < colors.count {
            let c = ColorMath.convertP3ToMixSpaceCPU(
                r: colors[i * 4],
                g: colors[i * 4 + 1],
                b: colors[i * 4 + 2],
                mode: colorSpaceMode
            )
            out[i * 3] = c.x
            out[i * 3 + 1] = c.y
            out[i * 3 + 2] = c.z
        }
        return out
    }
}
